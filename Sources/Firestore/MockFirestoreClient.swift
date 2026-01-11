//
//  MockFirestoreClient.swift
//
//  Created by EasyFirebaseSwift
//

import FirebaseFirestore
import Foundation

/// Mock implementation of FirestoreClientProtocol for unit testing.
///
/// This actor provides an in-memory implementation that allows testing
/// business logic without requiring a real Firebase connection.
///
/// ## Features
/// - In-memory storage for models
/// - Error injection for testing error handling
/// - Delay simulation for testing async behavior
/// - Controllable streams for testing real-time listeners
///
/// ## Example Usage
/// ```swift
/// let mock = MockFirestoreClient()
///
/// // Inject test data
/// let user = User(name: "John")
/// await mock.setMockData(user, for: "user-123")
///
/// // Use in tests
/// let result: User = try await mock.get(documentId: "user-123")
///
/// // Test error handling
/// await mock.setNextError(SomeError())
/// ```
public actor MockFirestoreClient: @preconcurrency FirestoreClientProtocol {

    // MARK: - Storage

    /// Type-erased storage for models, keyed by collection name then document ID
    private var storage: [String: [String: Any]] = [:]

    // MARK: - Stream Management

    /// Type-erased document listener continuations
    private var documentContinuations: [String: Any] = [:]

    /// Type-erased query listener continuations
    private var queryContinuations: [String: Any] = [:]

    // MARK: - Mock Configuration

    /// Error to throw on next operation (reset after use)
    private var _nextError: Error?

    /// Delay to simulate network latency (in nanoseconds)
    private var _simulatedDelayNanoseconds: UInt64?

    /// Counter for auto-generated document IDs
    private var idCounter = 0

    /// Firestore instance for creating DocumentReferences
    private let firestore: Firestore

    // MARK: - Initialization

    /// Creates a new MockFirestoreClient instance.
    /// - Parameter firestore: Firestore instance for creating DocumentReferences. Defaults to `Firestore.firestore()`.
    public init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    // MARK: - Write Operations

    @discardableResult
    public func write<Model: FirestoreModel>(
        _ model: Model,
        newDocumentIdIfNotExists: String?
    ) async throws -> DocumentReference {
        try await simulateDelay()
        try throwIfErrorSet()

        let collectionName = Model.collectionName
        let documentId: String

        if let existingId = model.id {
            documentId = existingId
        } else if let newId = newDocumentIdIfNotExists {
            documentId = newId
        } else {
            idCounter += 1
            documentId = "mock-doc-\(idCounter)"
        }

        // Store the model
        if storage[collectionName] == nil {
            storage[collectionName] = [:]
        }
        storage[collectionName]?[documentId] = model

        return firestore.collection(collectionName).document(documentId)
    }

    public func writeTransaction<Model: FirestoreModel, FieldValue>(
        _ model: Model,
        fieldPath: WritableKeyPath<Model, FieldValue>,
        fieldValue: FieldValue,
        beforeCommit: @escaping ((old: FieldValue, new: FieldValue)) -> FieldValue
    ) async throws {
        try await simulateDelay()
        try throwIfErrorSet()

        guard let documentId = model.id else {
            throw EasyFirebaseFirestoreError.refNotExists
        }

        let collectionName = Model.collectionName
        guard var existingModel = storage[collectionName]?[documentId] as? Model else {
            throw EasyFirebaseFirestoreError.notFound(
                ref: firestore.collection(collectionName).document(documentId)
            )
        }

        let oldValue = existingModel[keyPath: fieldPath]
        let newValue = beforeCommit((oldValue, fieldValue))
        existingModel[keyPath: fieldPath] = newValue

        storage[collectionName]?[documentId] = existingModel
    }

    // MARK: - Read Operations

    public func get<Model: FirestoreModel>(
        documentId: String,
        includeCache: Bool
    ) async throws -> Model {
        try await simulateDelay()
        try throwIfErrorSet()

        let collectionName = Model.collectionName
        guard let model = storage[collectionName]?[documentId] as? Model else {
            throw EasyFirebaseFirestoreError.notFound(
                ref: firestore.collection(collectionName).document(documentId)
            )
        }

        return model
    }

    public func get<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async throws -> [Model] {
        try await simulateDelay()
        try throwIfErrorSet()

        let collectionName = Model.collectionName
        guard let collection = storage[collectionName] else {
            return []
        }

        var models = collection.values.compactMap { $0 as? Model }

        // Apply limit
        if let limit = limit, models.count > limit {
            models = Array(models.prefix(limit))
        }

        return models
    }

    // MARK: - Delete Operations

    public func delete<Model: FirestoreModel>(_ model: Model) async throws {
        try await simulateDelay()
        try throwIfErrorSet()

        guard let documentId = model.id else {
            throw EasyFirebaseFirestoreError.refNotExists
        }

        let collectionName = Model.collectionName
        storage[collectionName]?[documentId] = nil
    }

    // MARK: - Listener Operations

    public func listen<Model: FirestoreModel>(
        documentId: String,
        includeCache: Bool
    ) -> AsyncThrowingStream<Model, Error> {
        let collectionName = Model.collectionName
        let key = "\(collectionName)/\(documentId)"
        let currentModel = storage[collectionName]?[documentId] as? Model

        return AsyncThrowingStream { continuation in
            // Store continuation
            Task { [weak self] in
                await self?.setDocumentContinuation(key: key, continuation: continuation)
            }

            // Emit current value if exists
            if let model = currentModel {
                continuation.yield(model)
            }

            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeDocumentContinuation(key: key)
                }
            }
        }
    }

    public func listen<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) -> AsyncThrowingStream<[Model], Error> {
        let collectionName = Model.collectionName
        let collection = storage[collectionName] ?? [:]
        var models = collection.values.compactMap { $0 as? Model }
        if let limit = limit, models.count > limit {
            models = Array(models.prefix(limit))
        }

        return AsyncThrowingStream { continuation in
            // Store continuation
            Task { [weak self] in
                await self?.setQueryContinuation(key: collectionName, continuation: continuation)
            }

            // Emit current values
            continuation.yield(models)

            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeQueryContinuation(key: collectionName)
                }
            }
        }
    }

    // MARK: - Listener Management

    public func stopListening<Model: FirestoreModel>(type: Model.Type) {
        let key = Model.collectionName
        if let continuation = queryContinuations[key] as? AsyncThrowingStream<[Model], Error>.Continuation {
            continuation.finish()
        }
        queryContinuations[key] = nil
    }

    public func stopListening<Model: FirestoreModel>(type: Model.Type, documentID: String) {
        let key = "\(Model.collectionName)/\(documentID)"
        if let continuation = documentContinuations[key] as? AsyncThrowingStream<Model, Error>.Continuation {
            continuation.finish()
        }
        documentContinuations[key] = nil
    }

    public func stopListeningAll() {
        documentContinuations.removeAll()
        queryContinuations.removeAll()
    }

    // MARK: - Test Helpers

    /// Sets the error to throw on the next operation.
    public func setNextError(_ error: Error?) {
        _nextError = error
    }

    /// Gets the current next error.
    public var nextError: Error? {
        _nextError
    }

    /// Sets the simulated delay in nanoseconds.
    public func setSimulatedDelay(nanoseconds: UInt64?) {
        _simulatedDelayNanoseconds = nanoseconds
    }

    /// Gets the current simulated delay.
    public var simulatedDelayNanoseconds: UInt64? {
        _simulatedDelayNanoseconds
    }

    /// Clears all stored data and resets mock state.
    public func reset() {
        storage.removeAll()
        documentContinuations.removeAll()
        queryContinuations.removeAll()
        _nextError = nil
        _simulatedDelayNanoseconds = nil
        idCounter = 0
    }

    /// Injects a model directly into storage for test setup.
    /// - Parameters:
    ///   - model: The model to inject.
    ///   - documentId: The document ID to use.
    public func setMockData<Model: FirestoreModel>(_ model: Model, for documentId: String) {
        let collectionName = Model.collectionName
        if storage[collectionName] == nil {
            storage[collectionName] = [:]
        }
        storage[collectionName]?[documentId] = model
    }

    /// Emits a value to document listeners for the specified document.
    /// Use this to simulate real-time updates in tests.
    /// - Parameters:
    ///   - model: The model to emit.
    ///   - documentId: The document ID.
    public func emitToListener<Model: FirestoreModel>(_ model: Model, for documentId: String) {
        let collectionName = Model.collectionName
        let key = "\(collectionName)/\(documentId)"

        // Update storage
        if storage[collectionName] == nil {
            storage[collectionName] = [:]
        }
        storage[collectionName]?[documentId] = model

        // Emit to listener
        if let continuation = documentContinuations[key] as? AsyncThrowingStream<Model, Error>.Continuation {
            continuation.yield(model)
        }
    }

    /// Emits an error to document listeners for the specified document.
    /// - Parameters:
    ///   - error: The error to emit.
    ///   - documentId: The document ID.
    ///   - type: The model type.
    public func emitErrorToListener<Model: FirestoreModel>(
        _ error: Error,
        for documentId: String,
        type: Model.Type
    ) {
        let key = "\(Model.collectionName)/\(documentId)"

        if let continuation = documentContinuations[key] as? AsyncThrowingStream<Model, Error>.Continuation {
            continuation.finish(throwing: error)
        }
        documentContinuations[key] = nil
    }

    /// Finishes the stream for a document listener.
    /// - Parameters:
    ///   - documentId: The document ID.
    ///   - type: The model type.
    public func finishListener<Model: FirestoreModel>(for documentId: String, type: Model.Type) {
        let key = "\(Model.collectionName)/\(documentId)"

        if let continuation = documentContinuations[key] as? AsyncThrowingStream<Model, Error>.Continuation {
            continuation.finish()
        }
        documentContinuations[key] = nil
    }

    /// Returns all stored models for a collection.
    /// Useful for test assertions.
    public func getAllStoredData<Model: FirestoreModel>(type: Model.Type) -> [String: Model] {
        guard let collection = storage[Model.collectionName] else {
            return [:]
        }

        var result: [String: Model] = [:]
        for (key, value) in collection {
            if let model = value as? Model {
                result[key] = model
            }
        }
        return result
    }

    // MARK: - Private Helpers

    private func simulateDelay() async throws {
        if let delay = _simulatedDelayNanoseconds {
            try await Task.sleep(nanoseconds: delay)
        }
    }

    private func throwIfErrorSet() throws {
        if let error = _nextError {
            _nextError = nil
            throw error
        }
    }

    private func setDocumentContinuation(key: String, continuation: Any) {
        documentContinuations[key] = continuation
    }

    private func removeDocumentContinuation(key: String) {
        documentContinuations[key] = nil
    }

    private func setQueryContinuation(key: String, continuation: Any) {
        queryContinuations[key] = continuation
    }

    private func removeQueryContinuation(key: String) {
        queryContinuations[key] = nil
    }
}
