//
//  FirestoreClientProtocol.swift
//
//  Created by EasyFirebaseSwift
//

import FirebaseFirestore
import Foundation

/// Protocol abstracting FirestoreClient for testability.
/// Allows dependency injection of mock implementations in unit tests.
public protocol FirestoreClientProtocol: Sendable {

    // MARK: - Write Operations

    /// Update document's data or Create new document if `model.ref` is nil.
    @discardableResult
    func write<Model: FirestoreModel>(
        _ model: Model,
        newDocumentIdIfNotExists: String?
    ) async throws -> DocumentReference

    /// Perform a transaction-based field update with conflict resolution.
    func writeTransaction<Model: FirestoreModel, FieldValue>(
        _ model: Model,
        fieldPath: WritableKeyPath<Model, FieldValue>,
        fieldValue: FieldValue,
        beforeCommit: @escaping ((old: FieldValue, new: FieldValue)) -> FieldValue
    ) async throws

    // MARK: - Read Operations

    /// Fetch a single document by ID.
    func get<Model: FirestoreModel>(
        documentId: String,
        includeCache: Bool
    ) async throws -> Model

    /// Fetch multiple documents with filtering and ordering.
    func get<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async throws -> [Model]

    // MARK: - Delete Operations

    /// Delete a document.
    func delete<Model: FirestoreModel>(_ model: Model) async throws

    // MARK: - Listener Operations

    /// Listen to a single document in real-time.
    func listen<Model: FirestoreModel>(
        documentId: String,
        includeCache: Bool
    ) -> AsyncThrowingStream<Model, Error>

    /// Listen to multiple documents with filtering in real-time.
    func listen<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) -> AsyncThrowingStream<[Model], Error>

    // MARK: - Listener Management

    /// Stop listening to all documents of a specific type.
    func stopListening<Model: FirestoreModel>(type: Model.Type)

    /// Stop listening to a specific document.
    func stopListening<Model: FirestoreModel>(type: Model.Type, documentID: String)

    /// Stop all active listeners.
    func stopListeningAll()
}

// MARK: - Convenience Methods

public extension FirestoreClientProtocol {

    /// Convenience write method with default nil for newDocumentIdIfNotExists.
    @discardableResult
    func write<Model: FirestoreModel>(_ model: Model) async throws -> DocumentReference {
        try await write(model, newDocumentIdIfNotExists: nil)
    }

    /// Convenience get method with default includeCache = true.
    func get<Model: FirestoreModel>(documentId: String) async throws -> Model {
        try await get(documentId: documentId, includeCache: true)
    }

    /// Convenience get method with all default parameters.
    func get<Model: FirestoreModel>() async throws -> [Model] {
        try await get(filter: [], includeCache: true, order: [], limit: nil)
    }

    /// Convenience get method with filter only.
    func get<Model: FirestoreModel>(filter: [FirestoreQueryFilter]) async throws -> [Model] {
        try await get(filter: filter, includeCache: true, order: [], limit: nil)
    }

    /// Convenience get method with filter and limit.
    func get<Model: FirestoreModel>(filter: [FirestoreQueryFilter], limit: Int?) async throws -> [Model] {
        try await get(filter: filter, includeCache: true, order: [], limit: limit)
    }

    /// Convenience listen method with default includeCache = true.
    func listen<Model: FirestoreModel>(documentId: String) -> AsyncThrowingStream<Model, Error> {
        listen(documentId: documentId, includeCache: true)
    }

    /// Convenience listen method with all default parameters.
    func listen<Model: FirestoreModel>() -> AsyncThrowingStream<[Model], Error> {
        listen(filter: [], includeCache: true, order: [], limit: nil)
    }

    /// Convenience listen method with filter only.
    func listen<Model: FirestoreModel>(filter: [FirestoreQueryFilter]) -> AsyncThrowingStream<[Model], Error> {
        listen(filter: filter, includeCache: true, order: [], limit: nil)
    }
}
