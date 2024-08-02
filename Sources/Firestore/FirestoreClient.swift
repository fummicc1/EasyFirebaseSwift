//
//  FirestoreClient.swift
//
//  Created by Fumiya Tanaka on 2020/11/11.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

public protocol FirestoreModel: Codable, CombineCompatible {
    static var collectionName: String { get }
    var id: String? { get }
    var ref: DocumentReference? { get set }
    var createdAt: Timestamp? { get set }
    var updatedAt: Timestamp? { get set }

    static func buildRef(
        firestore: Firestore?,
        id: String
    ) -> DocumentReference
}

public extension FirestoreModel {
    var id: String? {
        ref?.documentID
    }

    static func buildRef(firestore: Firestore?, id: String) -> DocumentReference {
        let firestore = firestore ?? Firestore.firestore()
        return firestore.collection(Self.collectionName).document(id)
    }
}

public protocol SubCollectionModel {
    static var parentModelType: FirestoreModel.Type { get }
}

public protocol FirestoreQueryFilter {
    var fieldPath: String? { get }
    
    func build<Model: FirestoreModel>(type: Model.Type) -> Query
    func intercept(from: Query) -> Query
}

public protocol FirestoreQueryOrder {
    var fieldPath: String { get }
    var isAscending: Bool { get }
    
    func intercept(from: Query) -> Query
}

public struct DefaultFirestoreQueryOrder: FirestoreQueryOrder {
    public var fieldPath: String
    public var isAscending: Bool
    
    public init(fieldPath: String, isAscending: Bool) {
        self.fieldPath = fieldPath
        self.isAscending = isAscending
    }
    
    public func intercept(from: Query) -> Query {
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

    public func intercept(from: Query) -> Query {
        guard let fieldPath = fieldPath, maxValue > minValue else {
            return from
        }
        return from
            .whereField(fieldPath, isGreaterThan: minValue)
            .whereField(fieldPath, isLessThan: maxValue)
    }

    public func build<Model>(type: Model.Type) -> Query where Model : FirestoreModel {
        let from = Firestore.firestore().collection(type.collectionName)
        guard let fieldPath = fieldPath, maxValue > minValue else {
            return from
        }
        return from
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
    
    public func intercept(from: Query) -> Query {

        guard let fieldPath = fieldPath else {
            return from
        }
        return from.whereField(fieldPath, isEqualTo: value as Any)
    }

    public func build<Model>(type: Model.Type) -> Query where Model : FirestoreModel {
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

    public func intercept(from: Query) -> Query {
        guard let fieldPath = fieldPath, !value.isEmpty else {
            return from
        }
        return from.whereField(fieldPath, in: value)
    }

    public func build<Model>(type: Model.Type) -> Query where Model : FirestoreModel {
        let from = Firestore.firestore().collection(type.collectionName)
        guard let fieldPath = fieldPath, !value.isEmpty else {
            return from
        }
        return from.whereField(fieldPath, in: value)
    }
}

public enum FirestoreClientError: Error {
    // Decode/Encode
    case failedToDecode(data: [String: Any]?)
    
    // Ref
    case alreadyExists(ref: DocumentReference)
    case notFound(ref: DocumentReference)

    // Timestamp
    case invalidTimestamp(createdAt: Timestamp?, updatedAt: Timestamp?)
}

public actor FirestoreClient {

    private let firestore = Firestore.firestore()
    private var documentListeners: [DocumentReference: ListenerRegistration] = [:]
    private var queryListeners: [Query: ListenerRegistration] = [:]
    
    public init() { }

    internal func set(ref: DocumentReference, documentListener: ListenerRegistration) {
        documentListeners[ref] = documentListener
    }

    public func writeTransaction<Model: FirestoreModel, FieldValue>(
        _ model: Model,
        fieldPath: WritableKeyPath<Model, FieldValue>,
        fieldValue: FieldValue,
        beforeCommit: @escaping ((FieldValue, FieldValue)) -> FieldValue,
    ) async throws -> DocumentReference {
        var model = model
        guard let ref = model.ref else {
            return
        }
        firestore.runTransaction { (transaction, errorPointeer) -> Any? in
            do {
                let snapshot = try transaction.getDocument(ref)
                let data = try snapshot.data(as: Model.self)
                let currentFieldValue = data[keyPath: fieldPath]
                let newFieldValue = handler((currentFieldValue, fieldValue))
                model[keyPath: fieldPath] = newFieldValue
                try transaction.setData(from: model, forDocument: ref)
            } catch {
                errorPointeer?.pointee = error as NSError
            }
            return nil
        } completion: { (_, error) in
            if let error = error {
                failure(error)
                return
            }
            success(ref)
        }
        
    }
    
    public func create<Model: FirestoreModel>(
        _ model: Model,
        documentId: String? = nil
    ) async throws -> DocumentReference {
        if let ref = model.ref {
            throw FirestoreClientError.alreadyExists(
                ref: ref
            )
        }

        if model.createdAt != nil || model.updatedAt != nil {
            throw FirestoreClientError.invalidTimestamp(
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }

        let ref: DocumentReference

        if let documentId = documentId {
            ref = firestore.collection(Model.collectionName).document(documentId)
        } else {
            ref = firestore.collection(Model.collectionName).document()
        }
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try ref.setData(from: model, merge: false) { error in
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
    
    /// Update document's data or Create new document if `model.ref` is nil.
    public func write<Model: FirestoreModel>(
        _ model: Model,
        documentId: String? = nil
    ) async throws -> DocumentReference {
        let ref: DocumentReference = if let ref = model.ref {
            ref
        } else {
            if let documentId = documentId {
                firestore.collection(Model.collectionName).document(documentId)
            } else {
                firestore.collection(Model.collectionName).document()
            }
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
            Task { [weak self] in
                await self?.set(ref: ref, documentListener: listener)
            }
        }
    }
    
    public func listen<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder],
        limit: Int?,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        let query = createQuery(modelType: Model.self, filter: filter)
            .build(order: order, limit: limit)
        let listener = query
            .addSnapshotListener { (snapshots, error) in
                if let error = error {
                    failure(error)
                    return
                }
                guard let snapshots = snapshots else {
                    return
                }
                if snapshots.metadata.isFromCache, includeCache == false {
                    return
                }
                do {
                    let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                    success(models)
                } catch {
                    failure(error)
                }
            }
        queryListeners[query]?.remove()
        queryListeners[query] = listener
    }
    
    public func get<Model: FirestoreModel>(
        uid: String,
        includeCache: Bool = true,
        success: @escaping (Model) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        firestore.collection(Model.collectionName).document(uid).getDocument { (snapshot, error) in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshot = snapshot else {
                return
            }
            if snapshot.metadata.isFromCache, includeCache == false {
                return
            }
            do {
                let model: Model = try FirestoreClient.putSnaphotTogether(snapshot)
                success(model)
            } catch {
                failure(error)
            }
        }
    }
    
    public func get<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder],
        limit: Int?,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        createQuery(modelType: Model.self, filter: filter)
            .build(order: order, limit: limit)
            .getDocuments { (snapshots, error) in
                if let error = error {
                    failure(error)
                    return
                }
                guard let snapshots = snapshots else {
                    return
                }
                if snapshots.metadata.isFromCache, includeCache == false {
                    return
                }
                do {
                    let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                    success(models)
                } catch {
                    failure(error)
                }
            }
    }
    
    public func delete<Model: FirestoreModel>(
        _ model: Model,
        success: @escaping () -> Void,
        failure: @escaping (Error) -> Void
    ) {
        guard let ref = model.ref else {
            return
        }
        ref.delete { (error) in
            if let error = error {
                failure(error)
                return
            }
            success()
        }
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
    
    public func delete<Model: FirestoreModel>(
        id: String,
        type: Model.Type,
        completion: ((Error?) -> Void)? = nil
    ) {
        firestore.collection(Model.collectionName).document(id).delete(completion: completion)
    }
    
    // MARK: Internal
    func listen<Model: FirestoreModel>(
        ref: DocumentReference,
        includeCache: Bool = true,
        success: @escaping (Model) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        let listener = ref.addSnapshotListener { snapshot, error in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshot = snapshot else {
                return
            }
            if snapshot.metadata.isFromCache, includeCache == false {
                return
            }
            do {
                let model: Model = try FirestoreClient.putSnaphotTogether(snapshot)
                success(model)
            } catch {
                failure(error)
            }
        }
        documentListeners[ref]?.remove()
        documentListeners[ref] = listener
    }
    
    func listen<Model: FirestoreModel>(
        ref: Query,
        includeCache: Bool = true,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        let listener = ref.addSnapshotListener { snapshots, error in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshots = snapshots else {
                return
            }
            if snapshots.metadata.isFromCache, includeCache == false {
                return
            }
            do {
                let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                success(models)
            } catch {
                failure(error)
            }
        }
        queryListeners[ref]?.remove()
        queryListeners[ref] = listener
    }
}

// MARK: SubCollection
extension FirestoreClient {
    
    public func create<Model: FirestoreModel & SubCollectionModel>(
        _ model: Model,
        documentId: String? = nil,
        parent parentUid: String,
        superParent superParentUid: String?,
        success: @escaping (DocumentReference) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        do {
            
            if model.ref != nil {
                failure(FirestoreClientError.alreadyExists)
                return
            }
            
            let ref: DocumentReference
            
            if let superParentUid = superParentUid, let superParentType = Model.parentModelType as? SubCollectionModel.Type {
                let superCollectionName = superParentType.parentModelType.collectionName
                let parentCollectionName = Model.parentModelType.collectionName
                let collectionName = Model.collectionName
                
                if let documentId = documentId {
                    ref = firestore.collection(Model.parentModelType.collectionName).document(parentUid)
                        .collection(Model.collectionName)
                        .document(documentId)
                } else {
                    ref = firestore.collection(superCollectionName).document(superParentUid)
                        .collection(parentCollectionName)
                        .document(parentUid)
                        .collection(collectionName)
                        .document()
                }
            } else {
                
                if let documentId = documentId {
                    ref = firestore.collection(Model.parentModelType.collectionName).document(parentUid)
                        .collection(Model.collectionName)
                        .document(documentId)
                } else {
                    ref = firestore.collection(Model.parentModelType.collectionName).document(parentUid)
                        .collection(Model.collectionName)
                        .document()
                }
            }
            
            if model.updatedAt != nil || model.createdAt != nil {
                failure(FirestoreClientError.invalidTimestamp(createdAt: Date?, updatedAt: Date?))
                return
            }
            
            try ref.setData(from: model, merge: false) { (error) in
                if let error = error {
                    failure(error)
                    return
                }
                success(ref)
            }
        } catch {
            failure(error)
        }
    }
    
    public func update<Model: FirestoreModel & SubCollectionModel>(
        _ model: Model,
        parent parentUid: String,
        superParent superParentUid: String?,
        success: @escaping () -> Void,
        failure: @escaping (Error) -> Void
    ) {
        do {
            var model = model
            guard var ref = model.ref else {
                failure(FirestoreClientError.notFound)
                return
            }
            
            if model.updatedAt == nil || model.createdAt == nil {
                failure(FirestoreClientError.invalidTimestamp(createdAt: Date?, updatedAt: Date?))
                return
            }

            if let superParentUid = superParentUid, let superParentType = Model.parentModelType as? SubCollectionModel.Type {
                let superCollectionName = superParentType.parentModelType.collectionName
                let parentCollectionName = Model.parentModelType.collectionName
                let collectionName = Model.collectionName

                let documentId = ref.documentID
                ref = firestore
                    .collection(superCollectionName)
                    .document(superParentUid)
                    .collection(parentCollectionName)
                    .document(parentUid)
                    .collection(collectionName)
                    .document(documentId)
            } else {

                let documentId = ref.documentID
                ref = firestore
                    .collection(Model.parentModelType.collectionName)
                    .document(parentUid)
                    .collection(Model.collectionName)
                    .document(documentId)
            }

            model.updatedAt = nil
            
            try ref.setData(from: model, merge: true) { (error) in
                if let error = error {
                    failure(error)
                    return
                }
                success()
            }
        } catch {
            failure(error)
        }
    }
    
    public func get<Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        superParent superParentUid: String?,
        filter: [FirestoreQueryFilter],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder],
        limit: Int?,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        createQueryOfSubCollection(
            parent: parentUid,
            superParent: superParentUid,
            modelType: Model.self,
            filter: filter
        )
        .build(order: order, limit: limit)
        .addSnapshotListener { (snapshots, error) in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshots = snapshots else {
                return
            }
            if snapshots.metadata.isFromCache, includeCache == false {
                return
            }
            do {
                let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                success(models)
            } catch {
                failure(error)
            }
        }
    }
    
    public func get<Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        superParent superParentUid: String?,
        docId: String,
        includeCache: Bool = true,
        success: @escaping (Model) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        let ref: DocumentReference
        if let superParent = superParentUid, let superParentType = Model.parentModelType as? SubCollectionModel.Type {
            ref = firestore
                .collection(superParentType.parentModelType.collectionName)
                .document(superParent)
                .collection(Model.parentModelType.collectionName)
                .document(parentUid)
                .collection(Model.collectionName)
                .document(docId)
        } else {
            ref = firestore
                .collection(Model.parentModelType.collectionName)
                .document(parentUid)
                .collection(Model.collectionName)
                .document(docId)
        }
        ref.getDocument { (snapshot, error) in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshot = snapshot else {
                return
            }
            if snapshot.metadata.isFromCache, includeCache == false {
                return
            }
            do {
                let model: Model = try FirestoreClient.putSnaphotTogether(snapshot)
                success(model)
            } catch {
                failure(error)
            }
        }
    }
    
    public func listen<Model: FirestoreModel & SubCollectionModel>(
        parent parentUID: String,
        uid: String,
        includeCache: Bool = true,
        success: @escaping (Model) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        let ref = firestore.collection(Model.parentModelType.collectionName).document(parentUID).collection(Model.collectionName).document(uid)
        let listener = ref.addSnapshotListener { (snapshot, error) in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshot = snapshot else {
                return
            }
            if snapshot.metadata.isFromCache, includeCache == false {
                return
            }
            do {
                let model: Model = try FirestoreClient.putSnaphotTogether(snapshot)
                success(model)
            } catch {
                failure(error)
            }
        }
        documentListeners[ref]?.remove()
        documentListeners[ref] = listener
    }
    
    public func listen<Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        superParent superParentUid: String?,
        filter: [FirestoreQueryFilter],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder],
        limit: Int?,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        let query = createQueryOfSubCollection(
            parent: parentUid,
            superParent: superParentUid,
            modelType: Model.self,
            filter: filter
        )
        .build(order: order, limit: limit)
        
        let listener = query
            .addSnapshotListener { (snapshots, error) in
                if let error = error {
                    failure(error)
                    return
                }
                guard let snapshots = snapshots else {
                    return
                }
                if snapshots.metadata.isFromCache, includeCache == false {
                    return
                }
                do {
                    let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                    success(models)
                } catch {
                    failure(error)
                }
            }
        queryListeners[query]?.remove()
        queryListeners[query] = listener
    }
    
    private func createQueryOfSubCollection
    <Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        superParent superParentUid: String?,
        modelType: Model.Type,
        filter: [FirestoreQueryFilter]
    ) -> Query {
        var query: Query
        if let superParentUid = superParentUid,
           let superParentType = Model.parentModelType as? SubCollectionModel.Type {
            let superCollectionName = superParentType.parentModelType.collectionName
            let parentCollectionName = Model.parentModelType.collectionName
            let collectionName = Model.collectionName
            query = firestore
                .collection(superCollectionName)
                .document(superParentUid)
                .collection(parentCollectionName)
                .document(parentUid)
                .collection(collectionName)
        } else {
            query = firestore
                .collection(modelType.parentModelType.collectionName)
                .document(parentUid)
                .collection(modelType.collectionName)
        }
        for element in filter {
            query = element.build(from: query)
        }
        return query
    }
}

// MARK: CollectionGroup
extension FirestoreClient {
    public func getCollectionGroup<Model: FirestoreModel>(
        collectionName: String,
        filter: FirestoreQueryFilter,
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        createQuery(
            from: firestore.collectionGroup(collectionName),
            filter: [filter]
        )
        .build(order: order, limit: limit)
        .getDocuments { (snapshots, error) in
            if let error = error {
                failure(error)
                 return
            }
            guard let snapshots = snapshots else {
                return
            }
            if snapshots.metadata.isFromCache, includeCache == false {
                return
            }
            do {
                let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                success(models)
            } catch {
                failure(error)
            }
        }
    }
    
    public func listenCollectionGroup<Model: FirestoreModel>(
        collectionName: String,
        filter: FirestoreQueryFilter,
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        
        let query = createQuery(
            from: firestore.collectionGroup(collectionName),
            filter: [filter]
        ).build(order: order, limit: limit)

        let listener = query.addSnapshotListener { (snapshots, error) in
            if let error = error {
                failure(error)
                 return
            }
            guard let snapshots = snapshots else {
                return
            }
            if snapshots.metadata.isFromCache, includeCache == false {
                return
            }
            do {
                let models: [Model] = try FirestoreClient.putSnaphotsTogether(snapshots)
                success(models)
            } catch {
                failure(error)
            }
        }
        queryListeners[query]?.remove()
        queryListeners[query] = listener
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

// MARK: internal common methods
extension FirestoreClient {
    
    static func putSnaphotsTogether<Model: FirestoreModel>(_ snapshots: QuerySnapshot) throws -> [Model] {
        let documents = snapshots.documents
        let models = try documents.map { document -> Model in
            let model = try document.data(as: Model.self)
            return model
        }
        return models
    }
    
    static func putSnaphotTogether<Model: FirestoreModel>(_ snapshot: DocumentSnapshot) throws -> Model {
        let model = try snapshot.data(as: Model.self)
        return model
    }
}

// MARK: Utility
public extension FirestoreClient {
    func updateDocumentID<Model: FirestoreModel>(of model: Model, newId: String) throws -> Model {
        var model = model
        let parent = model.ref?.parent
        model.ref = parent?.document(newId)
        return model
    }
}
