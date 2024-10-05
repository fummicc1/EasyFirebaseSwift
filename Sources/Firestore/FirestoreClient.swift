//
//  FirestoreClient.swift
//
//  Created by Fumiya Tanaka on 2020/11/11.
//

import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation

public protocol FirestoreModel: Codable, Identifiable {
    static var collectionName: String { get }
    var id: String? { get }
    var ref: DocumentReference? { get set }
    var createdAt: Timestamp? { get set }
    var updatedAt: Timestamp? { get set }

    static func buildRef(
        firestore: Firestore?,
        id: String
    ) -> DocumentReference

    static func generateDocumentId() -> String
}

extension FirestoreModel {
    public var id: String? {
        ref?.documentID
    }

    public static func buildRef(firestore: Firestore?, id: String) -> DocumentReference {
        let firestore = firestore ?? Firestore.firestore()
        return firestore.collection(Self.collectionName).document(id)
    }

    public static func generateDocumentId() -> String {
        return Firestore.firestore().collection(Self.collectionName).document().documentID
    }
}

public protocol SubCollectionModel: FirestoreModel {
    static var parentModelType: (any FirestoreModel).Type { get }
    static var parentCollectionName: String { get }
    var parentDocumentRef: DocumentReference { get set }
}

public protocol FirestoreQueryFilter {
    var fieldPath: String? { get }

    func build<Model: FirestoreModel>(type: Model.Type) -> Query
    func build(from: Query) -> Query
}

public struct FirestoreQueryOrder {
    public var fieldPath: String
    public var isAscending: Bool

    public init(fieldPath: String, isAscending: Bool) {
        self.fieldPath = fieldPath
        self.isAscending = isAscending
    }

    public func build(from: Query) -> Query {
        from.order(by: fieldPath, descending: !isAscending)
    }
}

public struct FirestoreRangeFilter<Value: Comparable>: FirestoreQueryFilter {
    public var fieldPath: String?
    public var minValue: Value
    private var maxValue: Value

    public init(fieldPath: String? = nil, minValue: Value, maxValue: Value) {
        self.fieldPath = fieldPath
        self.minValue = minValue
        self.maxValue = maxValue
    }

    public func build(from: Query) -> Query {
        guard let fieldPath = fieldPath, maxValue > minValue else {
            return from
        }
        return
            from
            .whereField(fieldPath, isGreaterThan: minValue)
            .whereField(fieldPath, isLessThan: maxValue)
    }

    public func build<Model>(type: Model.Type) -> Query where Model: FirestoreModel {
        let from = Firestore.firestore().collection(type.collectionName)
        guard let fieldPath = fieldPath, maxValue > minValue else {
            return from
        }
        return
            from
            .whereField(fieldPath, isGreaterThan: minValue)
            .whereField(fieldPath, isLessThan: maxValue)
    }
}

public struct FirestoreEqualFilter: FirestoreQueryFilter {
    public var fieldPath: String?
    public var value: Any?

    public init(fieldPath: String?, value: Any?) {
        self.fieldPath = fieldPath
        self.value = value
    }

    public func build(from: Query) -> Query {

        guard let fieldPath = fieldPath else {
            return from
        }
        return from.whereField(fieldPath, isEqualTo: value as Any)
    }

    public func build<Model>(type: Model.Type) -> Query where Model: FirestoreModel {
        let from = Firestore.firestore().collection(type.collectionName)
        guard let fieldPath = fieldPath else {
            return from
        }
        return from.whereField(fieldPath, isEqualTo: value as Any)
    }
}

public struct FirestoreContainFilter: FirestoreQueryFilter {

    public var fieldPath: String?
    public var value: [Any]

    public init(fieldPath: String?, value: [Any]) {
        self.fieldPath = fieldPath
        self.value = value
    }

    public func build(from: Query) -> Query {
        guard let fieldPath = fieldPath, !value.isEmpty else {
            return from
        }
        return from.whereField(fieldPath, in: value)
    }

    public func build<Model>(type: Model.Type) -> Query where Model: FirestoreModel {
        let from = Firestore.firestore().collection(type.collectionName)
        guard let fieldPath = fieldPath, !value.isEmpty else {
            return from
        }
        return from.whereField(fieldPath, in: value)
    }
}

public enum EasyFirebaseFirestoreError: Error {
    // Decode/Encode
    case failedToDecode(data: [String: Any]?)

    // Ref
    case alreadyExists(ref: DocumentReference)
    case notFound(ref: DocumentReference)

    // Timestamp
    case invalidTimestamp(createdAt: Timestamp?, updatedAt: Timestamp?)

    case refNotExists
}

public actor FirestoreClient {

    private let firestore = Firestore.firestore()
    private var documentListeners: [DocumentReference: ListenerRegistration] = [:]
    private var queryListeners: [Query: ListenerRegistration] = [:]

    public init() {}

}
// MARK: - FirestoreModel
extension FirestoreClient {

    // MARK: Write

    public func writeTransaction<Model: FirestoreModel, FieldValue>(
        _ model: Model,
        fieldPath: WritableKeyPath<Model, FieldValue>,
        fieldValue: FieldValue,
        beforeCommit: @escaping ((old: FieldValue, new: FieldValue)) -> FieldValue
    ) async throws {
        var model = model
        guard let ref = model.ref else {
            throw EasyFirebaseFirestoreError.refNotExists
        }
        _ = try await firestore.runTransaction { transaction, errorPointeer in
            do {
                let snapshot = try transaction.getDocument(ref)
                let data = try snapshot.data(as: Model.self)
                let currentFieldValue = data[keyPath: fieldPath]
                let newFieldValue = beforeCommit((currentFieldValue, fieldValue))
                model[keyPath: fieldPath] = newFieldValue
                try transaction.setData(from: model, forDocument: ref)
            } catch {
                errorPointeer?.pointee = error as NSError
            }
            return
        }
    }

    /// Update document's data or Create new document if `model.ref` is nil.
    public func write<Model: FirestoreModel>(
        _ model: Model,
        newDocumentIdIfNotExists: String? = nil
    ) async throws -> DocumentReference {
        let ref: DocumentReference
        if let existingRef = model.ref {
            ref = existingRef
        } else {
            let newId = newDocumentIdIfNotExists ?? Model.generateDocumentId()
            ref = Model.buildRef(firestore: firestore, id: newId)
        }

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try ref.setData(from: model, merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: ref)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: Get
    public func get<Model: FirestoreModel>(
        documentId: String,
        includeCache: Bool = true
    ) async throws -> Model {
        let ref = Model.buildRef(firestore: firestore, id: documentId)
        let snapshot = try await ref.getDocument(source: includeCache ? .default : .server)

        guard snapshot.exists else {
            throw EasyFirebaseFirestoreError.notFound(ref: ref)
        }

        return try FirestoreClient.putSnaphotTogether(snapshot)
    }

    public func get<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async throws -> [Model] {
        let query = createQuery(modelType: Model.self, filter: filter)
            .build(order: order, limit: limit)
        let snapshot = try await query.getDocuments(source: includeCache ? .default : .server)
        return try FirestoreClient.putSnaphotsTogether(snapshot)
    }

    // MARK: Listen

    public func listen<Model: FirestoreModel>(
        documentId: String,
        includeCache: Bool = true
    ) -> AsyncThrowingStream<Model, Error> {
        let ref = Model.buildRef(firestore: firestore, id: documentId)
        documentListeners[ref]?.remove()
        return AsyncThrowingStream { [weak self] continuation in
            let listener = ref.addSnapshotListener(
                includeMetadataChanges: includeCache
            ) { snapshot, error in
                if let error = error {
                    continuation.yield(with: .failure(error))
                    return
                }
                guard let snapshot = snapshot else {
                    return
                }
                let isCache = snapshot.metadata.isFromCache
                if isCache, !includeCache {
                    return
                }
                do {
                    let model = try snapshot.data(as: Model.self)
                    continuation.yield(model)
                } catch {
                    continuation.yield(with: .failure(error))
                }
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
            Task {
                await self?.documentListeners[ref]?.remove()
                await self?.setListener(key: ref, value: listener)
            }
        }
    }

    public func listen<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) -> AsyncThrowingStream<[Model], Error> {
        let query = createQuery(modelType: Model.self, filter: filter)
            .build(
                order: order,
                limit: limit
            )
        queryListeners[query]?.remove()
        return AsyncThrowingStream { [weak self] continuation in
            let listener = query.addSnapshotListener { (snapshots, error) in
                if let error = error {
                    continuation.yield(with: .failure(error))
                    return
                }
                guard let snapshots = snapshots else {
                    return
                }
                if !includeCache, snapshots.metadata.isFromCache {
                    // Ignore this event if `includeCache` is `false` and the source is from cache.
                    return
                }
                do {
                    let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                    continuation.yield(models)
                } catch {
                    continuation.yield(with: .failure(error))
                }
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
            Task {
                await self?.queryListeners[query]?.remove()
                await self?.setListener(key: query, value: listener)
            }
        }
    }

    // MARK: Delete

    public func delete<Model: FirestoreModel>(_ model: Model) async throws {
        guard let ref = model.ref else {
            throw EasyFirebaseFirestoreError.refNotExists
        }
        try await ref.delete()
    }

    private func createQuery<Model: FirestoreModel>(
        modelType: Model.Type,
        filter: [FirestoreQueryFilter]
    ) -> Query {
        var query: Query = firestore.collection(modelType.collectionName)
        for element in filter {
            query = element.build(from: query)
        }
        return query
    }

    // MARK: Stop Listener

    public func stopListening<Model: FirestoreModel>(type: Model.Type) {
        let query = firestore.collection(type.collectionName)
        queryListeners[query]?.remove()
    }

    /// Not applicable to SubCollectionModel
    public func stopListening<Model: FirestoreModel>(type: Model.Type, documentID: String) {
        let ref = firestore.collection(type.collectionName).document(documentID)
        stopListening(ref: ref)
    }

    public func stopListening(ref: DocumentReference) {
        documentListeners[ref]?.remove()
    }

    /// If you want to stop listening to SubCollectionModel, please use this method
    public func stopListeningAll() {
        documentListeners.forEach({ $0.value.remove() })
        queryListeners.forEach({ $0.value.remove() })
    }

    // MARK: Internal
    internal func setListener(
        key ref: DocumentReference, value documentListener: ListenerRegistration
    ) {
        documentListeners[ref] = documentListener
    }

    internal func setListener(key query: Query, value documentListener: ListenerRegistration) {
        queryListeners[query] = documentListener
    }
}

// MARK: - SubCollectionModel
extension FirestoreClient {

    public func create<Model: SubCollectionModel>(_ model: Model) async throws {
        guard let ref = model.ref else {
            throw EasyFirebaseFirestoreError.refNotExists
        }

        if model.updatedAt != nil || model.createdAt != nil {
            throw EasyFirebaseFirestoreError.invalidTimestamp(
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try ref.setData(from: model, merge: false) { (error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: ())
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func update<Model: FirestoreModel & SubCollectionModel>(_ model: Model) async throws {
        guard let ref = model.ref else {
            throw EasyFirebaseFirestoreError.refNotExists
        }

        if model.updatedAt == nil || model.createdAt == nil {
            throw EasyFirebaseFirestoreError.invalidTimestamp(
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try ref.setData(from: model, merge: false) { (error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: ())
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func get<Model: SubCollectionModel>(
        parent parentDocumentId: String,
        filter: [FirestoreQueryFilter] = [],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async throws -> [Model] {
        let snapshot = try await createQueryOfSubCollection(
            parent: parentDocumentId,
            modelType: Model.self,
            filter: filter,
            order: order,
            limit: limit
        )
        .getDocuments()

        return try FirestoreClient.putSnaphotsTogether(snapshot)
    }

    public func get<Model: SubCollectionModel>(
        documentId: String,
        parent parentUid: String,
        includeCache: Bool = true
    ) async throws -> Model {
        let collectionName = Model.parentCollectionName
        let ref: DocumentReference = firestore.collection(collectionName)
            .document(parentUid)
            .collection(Model.collectionName)
            .document(documentId)

        let snapshot = try await ref.getDocument()
        return try FirestoreClient.putSnaphotTogether(snapshot)

    }

    public func listen<Model: FirestoreModel & SubCollectionModel>(
        parentDocumentId parentUID: String,
        documentId: String,
        filter: [FirestoreQueryFilter],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) -> AsyncThrowingStream<Model, Error> {
        let ref = firestore.collection(Model.parentCollectionName).document(parentUID)
            .collection(Model.collectionName).document(documentId)
        return AsyncThrowingStream { [weak self] continuation in
            let listener = ref.addSnapshotListener(
                includeMetadataChanges: includeCache
            ) { snapshot, error in
                if let error = error {
                    continuation.yield(with: .failure(error))
                    return
                }
                guard let snapshot = snapshot else {
                    return
                }
                let isCache = snapshot.metadata.isFromCache
                if isCache, !includeCache {
                    return
                }
                do {
                    let model = try snapshot.data(as: Model.self)
                    continuation.yield(model)
                } catch {
                    continuation.yield(with: .failure(error))
                }
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
            Task {
                await self?.documentListeners[ref]?.remove()
                await self?.setListener(key: ref, value: listener)
            }
        }

    }

    public func listen<Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        superParent superParentUid: String?,
        filter: [FirestoreQueryFilter],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) -> AsyncThrowingStream<[Model], any Error> {
        let query = createQueryOfSubCollection(
            parent: parentUid,
            modelType: Model.self,
            filter: filter,
            order: order,
            limit: limit
        )

        return AsyncThrowingStream { [weak self] continuation in
            let listener = query.addSnapshotListener { (snapshots, error) in
                if let error = error {
                    continuation.yield(with: .failure(error))
                    return
                }
                guard let snapshots = snapshots else {
                    return
                }
                if !includeCache, snapshots.metadata.isFromCache {
                    // Ignore this event if `includeCache` is `false` and the source is from cache.
                    return
                }
                do {
                    let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                    continuation.yield(models)
                } catch {
                    continuation.yield(with: .failure(error))
                }
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
            Task {
                await self?.queryListeners[query]?.remove()
                await self?.setListener(key: query, value: listener)
            }
        }
    }

    private func createQueryOfSubCollection<Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        modelType: Model.Type,
        filter: [FirestoreQueryFilter],
        order: [FirestoreQueryOrder],
        limit: Int?
    ) -> Query {
        var query: Query =
            firestore
            .collection(modelType.parentCollectionName)
            .document(parentUid)
            .collection(modelType.collectionName)

        for element in filter {
            query = element.build(from: query).build(order: order, limit: limit)
        }
        return query
    }
}

// MARK: - CollectionGroup
extension FirestoreClient {
    public func getCollectionGroup<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter] = [],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) async throws -> [Model] {
        let collectionName = Model.collectionName
        let snapshots = try await createQuery(
            from: firestore.collectionGroup(collectionName),
            filter: filter
        )
        .build(order: order, limit: limit)
        .getDocuments(source: includeCache ? .default : .server)

        let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
        return models
    }

    public func listenCollectionGroup<Model: FirestoreModel>(
        collectionName: String,
        filter: [FirestoreQueryFilter] = [],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder] = [],
        limit: Int? = nil
    ) -> AsyncThrowingStream<[Model], Error> {

        let query = createQuery(
            from: firestore.collectionGroup(collectionName),
            filter: filter
        ).build(order: order, limit: limit)

        return AsyncThrowingStream { [weak self] continuation in
            let listener = query.addSnapshotListener { (snapshots, error) in
                if let error = error {
                    continuation.yield(with: .failure(error))
                    return
                }
                guard let snapshots = snapshots else {
                    return
                }
                if !includeCache, snapshots.metadata.isFromCache {
                    // Ignore this event if `includeCache` is `false` and the source is from cache.
                    return
                }
                do {
                    let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                    continuation.yield(models)
                } catch {
                    continuation.yield(with: .failure(error))
                }
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
            Task {
                await self?.queryListeners[query]?.remove()
                await self?.setListener(key: query, value: listener)
            }
        }
    }

    private func createQuery(from ref: Query, filter: [FirestoreQueryFilter]) -> Query {
        var query: Query = ref
        for element in filter {
            query = element.build(from: query)
        }
        return query
    }
}

// MARK: Order
extension Query {
    func build(order: [FirestoreQueryOrder], limit: Int?) -> Query {
        var ref = self
        order.forEach({ order in
            ref = order.build(from: ref)
        })
        if let limit = limit {
            return ref.limit(to: limit)
        }
        return ref
    }
}

// MARK: - Internal common methods
extension FirestoreClient {

    static func putSnaphotsTogether<Model: FirestoreModel>(_ snapshots: QuerySnapshot) throws
        -> [Model]
    {
        let documents = snapshots.documents
        let models = try documents.map { document -> Model in
            let model = try document.data(as: Model.self)
            return model
        }
        return models
    }

    static func putSnaphotTogether<Model: FirestoreModel>(_ snapshot: DocumentSnapshot) throws
        -> Model
    {
        let model = try snapshot.data(as: Model.self)
        return model
    }
}
