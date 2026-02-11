//
//  FirestoreClientType.swift
//  EasyFirebaseFirestore
//
//  Created by Fumiya Tanaka on 2025/02/11.
//

import FirebaseFirestore

/// A protocol abstracting FirestoreClient for dependency injection and testing.
///
/// All methods are marked `async` so that both actor-isolated implementations
/// (where actor isolation satisfies the async requirement per SE-0306)
/// and regular class-based mocks can conform.
///
/// `writeTransaction` is intentionally excluded due to its complex signature
/// (`WritableKeyPath` + tuple closure). It can be added later if needed.
///
/// @mockable
public protocol FirestoreClientType {

    // MARK: - FirestoreModel - Write

    @discardableResult
    func write<Model: FirestoreModel>(
        _ model: Model,
        newDocumentIdIfNotExists: String?
    ) async throws -> DocumentReference

    // MARK: - FirestoreModel - Get

    func get<Model: FirestoreModel>(
        documentId: String,
        includeCache: Bool
    ) async throws -> Model

    func get<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async throws -> [Model]

    // MARK: - FirestoreModel - Listen

    func listen<Model: FirestoreModel>(
        documentId: String,
        includeCache: Bool
    ) async -> AsyncThrowingStream<Model, Error>

    func listen<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async -> AsyncThrowingStream<[Model], Error>

    func listenChanges<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async -> AsyncThrowingStream<[FirestoreDocumentChange<Model>], Error>

    // MARK: - FirestoreModel - Delete

    func delete<Model: FirestoreModel>(_ model: Model) async throws

    // MARK: - SubCollectionModel - Create/Update

    func create<Model: SubCollectionModel>(_ model: Model) async throws

    func update<Model: FirestoreModel & SubCollectionModel>(
        _ model: Model
    ) async throws

    // MARK: - SubCollectionModel - Get

    func get<Model: SubCollectionModel>(
        parent parentDocumentId: String,
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async throws -> [Model]

    func get<Model: SubCollectionModel>(
        documentId: String,
        parent parentUid: String,
        includeCache: Bool
    ) async throws -> Model

    // MARK: - SubCollectionModel - Listen

    func listen<Model: FirestoreModel & SubCollectionModel>(
        parentDocumentId: String,
        documentId: String,
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async -> AsyncThrowingStream<Model, Error>

    func listen<Model: FirestoreModel & SubCollectionModel>(
        parent: String,
        superParent: String?,
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async -> AsyncThrowingStream<[Model], Error>

    func listenChanges<Model: FirestoreModel & SubCollectionModel>(
        parent: String,
        superParent: String?,
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async -> AsyncThrowingStream<[FirestoreDocumentChange<Model>], Error>

    // MARK: - CollectionGroup

    func getCollectionGroup<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async throws -> [Model]

    func listenCollectionGroup<Model: FirestoreModel>(
        collectionName: String,
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async -> AsyncThrowingStream<[Model], Error>

    func listenCollectionGroupChanges<Model: FirestoreModel>(
        collectionName: String,
        filter: [FirestoreQueryFilter],
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async -> AsyncThrowingStream<[FirestoreDocumentChange<Model>], Error>

    // MARK: - Listener Management

    func stopListening<Model: FirestoreModel>(type: Model.Type) async
    func stopListening<Model: FirestoreModel>(
        type: Model.Type,
        documentID: String
    ) async
    func stopListening(ref: DocumentReference) async
    func stopListeningAll() async
}

// MARK: - Convenience Methods (Default Parameters)

extension FirestoreClientType {

    // MARK: FirestoreModel - Write

    @discardableResult
    public func write<Model: FirestoreModel>(
        _ model: Model
    ) async throws -> DocumentReference {
        try await write(model, newDocumentIdIfNotExists: nil)
    }

    // MARK: FirestoreModel - Get

    public func get<Model: FirestoreModel>(
        documentId: String
    ) async throws -> Model {
        try await get(documentId: documentId, includeCache: true)
    }

    public func get<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async throws -> [Model] {
        try await get(
            filter: filter,
            includeCache: true,
            order: order,
            limit: limit
        )
    }

    public func get<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        includeCache: Bool,
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async throws -> [Model] {
        try await get(
            filter: filter,
            includeCache: includeCache,
            order: order,
            limit: limit
        )
    }

    // MARK: FirestoreModel - Listen

    public func listen<Model: FirestoreModel>(
        documentId: String
    ) async -> AsyncThrowingStream<Model, Error> {
        await listen(documentId: documentId, includeCache: true)
    }

    public func listen<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async -> AsyncThrowingStream<[Model], Error> {
        await listen(
            filter: filter,
            includeCache: true,
            order: order,
            limit: limit
        )
    }

    public func listen<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        includeCache: Bool,
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async -> AsyncThrowingStream<[Model], Error> {
        await listen(
            filter: filter,
            includeCache: includeCache,
            order: order,
            limit: limit
        )
    }

    public func listenChanges<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async -> AsyncThrowingStream<[FirestoreDocumentChange<Model>], Error> {
        await listenChanges(
            filter: filter,
            includeCache: true,
            order: order,
            limit: limit
        )
    }

    public func listenChanges<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        includeCache: Bool,
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async -> AsyncThrowingStream<[FirestoreDocumentChange<Model>], Error> {
        await listenChanges(
            filter: filter,
            includeCache: includeCache,
            order: order,
            limit: limit
        )
    }

    // MARK: SubCollectionModel - Get

    public func get<Model: SubCollectionModel>(
        parent parentDocumentId: String,
        filter: [FirestoreQueryFilter] = [],
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async throws -> [Model] {
        try await get(
            parent: parentDocumentId,
            filter: filter,
            includeCache: true,
            order: order,
            limit: limit
        )
    }

    public func get<Model: SubCollectionModel>(
        parent parentDocumentId: String,
        filter: [FirestoreQueryFilter] = [],
        includeCache: Bool,
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async throws -> [Model] {
        try await get(
            parent: parentDocumentId,
            filter: filter,
            includeCache: includeCache,
            order: order,
            limit: limit
        )
    }

    public func get<Model: SubCollectionModel>(
        documentId: String,
        parent parentUid: String
    ) async throws -> Model {
        try await get(
            documentId: documentId,
            parent: parentUid,
            includeCache: true
        )
    }

    // MARK: SubCollectionModel - Listen

    public func listen<Model: FirestoreModel & SubCollectionModel>(
        parent: String,
        superParent: String? = nil,
        filter: [FirestoreQueryFilter],
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async -> AsyncThrowingStream<[Model], Error> {
        await listen(
            parent: parent,
            superParent: superParent,
            filter: filter,
            includeCache: true,
            order: order,
            limit: limit
        )
    }

    public func listenChanges<Model: FirestoreModel & SubCollectionModel>(
        parent: String,
        superParent: String? = nil,
        filter: [FirestoreQueryFilter],
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async -> AsyncThrowingStream<[FirestoreDocumentChange<Model>], Error> {
        await listenChanges(
            parent: parent,
            superParent: superParent,
            filter: filter,
            includeCache: true,
            order: order,
            limit: limit
        )
    }

    // MARK: CollectionGroup

    public func getCollectionGroup<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async throws -> [Model] {
        try await getCollectionGroup(
            filter: filter,
            includeCache: true,
            order: order,
            limit: limit
        )
    }

    public func listenCollectionGroup<Model: FirestoreModel>(
        collectionName: String,
        filter: [FirestoreQueryFilter] = [],
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async -> AsyncThrowingStream<[Model], Error> {
        await listenCollectionGroup(
            collectionName: collectionName,
            filter: filter,
            includeCache: true,
            order: order,
            limit: limit
        )
    }

    public func listenCollectionGroupChanges<Model: FirestoreModel>(
        collectionName: String,
        filter: [FirestoreQueryFilter] = [],
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async -> AsyncThrowingStream<[FirestoreDocumentChange<Model>], Error> {
        await listenCollectionGroupChanges(
            collectionName: collectionName,
            filter: filter,
            includeCache: true,
            order: order,
            limit: limit
        )
    }
}
