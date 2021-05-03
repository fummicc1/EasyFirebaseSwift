//
//  FirestoreClient.swift
//
//  Created by Fumiya Tanaka on 2020/11/11.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

public protocol FirestoreModel: Codable {
    static var singleIdentifier: String { get }
    static var arrayIdentifier: String { get }
    static var collectionName: String { get }
    var uid: String? { get }
    var ref: DocumentReference? { get }
    var createdAt: Timestamp? { get set }
    var updatedAt: Timestamp? { get set }
}

public extension FirestoreModel {
    var uid: String? {
        ref?.documentID
    }
}

public protocol SubCollectionModel {
    static var parentModelType: FirestoreModel.Type { get }
}

public protocol FirestoreFilterModel {
    var fieldPath: String? { get }
    var value: Any { get }
    
    func build(from: Query) -> Query
}

public protocol FirestoreOrderModel {
    var fieldPath: String { get }
    var isAscending: Bool { get }
    
    func build(from: Query) -> Query
}

public struct FirestoreOrderModelImpl: FirestoreOrderModel {
    public var fieldPath: String
    public var isAscending: Bool
    
    public func build(from: Query) -> Query {
        from.order(by: fieldPath, descending: !isAscending)
    }
}

public struct FirestoreFilterRangeModel: FirestoreFilterModel {
    public var fieldPath: String?
    public var value: Any
    
    public func build(from: Query) -> Query {
        guard let fieldPath = fieldPath, let value = value as? [Any] else {
            return from
        }
        return from.whereField(fieldPath, in: value)
    }
}

public struct FirestoreFilterEqualModel: FirestoreFilterModel {
    public var fieldPath: String?
    public var value: Any
    
    public func build(from: Query) -> Query {
        
        guard let fieldPath = fieldPath else {
            return from
        }
        return from.whereField(fieldPath, isEqualTo: value)
    }
}

public enum FirestoreClientError: Error {
    // Decode/Encode
    case failedToDecode(data: [String: Any]?)
    
    // Ref
    case alreadyExistsDocumentReferenceInCreateModel
    case notExistsDocumentReferenceInUpdateModel
    
    // Timestamp
    case occureTimestampExceptionInCreateModel
    case occureTimestampExceptionInUpdateModel
}

public class FirestoreClient {
    
    private let firestore = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    public init() { }
    
    public func writeTransaction<Model: FirestoreModel, FieldValue>(
        _ model: Model,
        fieldPath: WritableKeyPath<Model, FieldValue>,
        fieldValue: FieldValue,
        handler: @escaping ((FieldValue, FieldValue)) -> FieldValue,
        success: @escaping (DocumentReference) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        var model = model
        guard let ref = model.ref else {
            return
        }
        firestore.runTransaction { (transaction, errorPointeer) -> Any? in
            do {
                let snapshot = try transaction.getDocument(ref)
                guard let data = try snapshot.data(as: Model.self) else {
                    return nil
                }
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
    
    public func write<Model: FirestoreModel>(
        _ model: Model,
        merge: Bool,
        success: @escaping (DocumentReference) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        if merge {
            update(model, success: { success(model.ref!) }, failure: failure)
        } else {
            create(model, success: success, failure: failure)
        }
    }
    
    public func create<Model: FirestoreModel>(
        _ model: Model,
        success: @escaping (DocumentReference) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        do {
            if model.ref != nil {
                failure(FirestoreClientError.alreadyExistsDocumentReferenceInCreateModel)
                return
            }
            
            if model.createdAt != nil || model.updatedAt != nil {
                failure(FirestoreClientError.occureTimestampExceptionInCreateModel)
                return
            }
            
            let ref = firestore.collection(Model.collectionName).document()
            try ref.setData(from: model, merge: false) { error in
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
    
    public func update<Model: FirestoreModel>(
        _ model: Model,
        success: @escaping () -> Void,
        failure: @escaping (Error) -> Void
    ) {
        do {
            guard let ref = model.ref else {
                failure(FirestoreClientError.notExistsDocumentReferenceInUpdateModel)
                return
            }
            
            if model.createdAt == nil {
                failure(FirestoreClientError.occureTimestampExceptionInUpdateModel)
                return
            }
            
            try ref.setData(from: model, merge: true) { error in
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
    
    public func listen<Model: FirestoreModel>(
        uid: String,
        includeCache: Bool = true,
        success: @escaping (Model) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        let listener = firestore.collection(Model.collectionName)
            .document(uid)
            .addSnapshotListener { (snapshot, error) in
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
                guard let model = try snapshot.data(as: Model.self) else {
                    throw FirestoreClientError.failedToDecode(data: snapshot.data())
                }
                success(model)
            } catch {
                failure(error)
            }
        }
        listeners[Model.singleIdentifier]?.remove()
        listeners[Model.singleIdentifier] = listener
    }
    
    public func listen<Model: FirestoreModel>(
        filter: [FirestoreFilterModel],
        includeCache: Bool = true,
        order: [FirestoreOrderModel],
        limit: Int?,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        let listener = createQuery(modelType: Model.self, filter: filter)
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
            let documents = snapshots.documents
            var models: [Model] = []
            for document in documents {
                guard let model = try? document.data(as: Model.self) else {
                    continue
                }
                models.append(model)
            }
            success(models)
        }
        listeners[Model.arrayIdentifier]?.remove()
        listeners[Model.arrayIdentifier] = listener
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
                guard let model = try snapshot.data(as: Model.self) else {
                    throw FirestoreClientError.failedToDecode(data: snapshot.data())
                }
                success(model)
            } catch {
                failure(error)
            }
        }
    }
    
    public func get<Model: FirestoreModel>(
        filter: [FirestoreFilterModel],
        includeCache: Bool = true,
        order: [FirestoreOrderModel],
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
            let documents = snapshots.documents
            var models: [Model] = []
            for document in documents {
                guard let model = try? document.data(as: Model.self) else {
                    continue
                }
                models.append(model)
            }
            success(models)
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
        filter: [FirestoreFilterModel]
    ) -> Query {
        var query: Query = firestore.collection(modelType.collectionName)
        for element in filter {
            query = element.build(from: query)
        }
        return query
    }
    
    public func stopListening<Model: FirestoreModel>(type: Model.Type) {
        listeners[Model.arrayIdentifier]?.remove()
        listeners[Model.singleIdentifier]?.remove()
    }
    
    public func delete<Model: FirestoreModel>(
        id: String,
        type: Model.Type,
        completion: ((Error?) -> Void)? = nil
    ) {
        firestore.collection(Model.collectionName).document(id).delete(completion: completion)
    }
}

// MARK: SubCollection
extension FirestoreClient {
    public func write<Model: FirestoreModel & SubCollectionModel>(
        _ model: Model,
        parent parentUid: String,
        superParent superParentUid: String?,
        merge: Bool,
        success: @escaping (DocumentReference) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        if merge {
            update(
                model,
                parent: parentUid,
                superParent: superParentUid,
                success: { success(model.ref!) },
                failure: failure
            )
        } else {
            create(model, success: success, failure: failure)
        }
    }
    
    public func create<Model: FirestoreModel & SubCollectionModel>(
        _ model: Model,
        parent parentUid: String,
        superParent superParentUid: String?,
        success: @escaping (DocumentReference) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        do {
            
            if model.ref != nil {
                failure(FirestoreClientError.alreadyExistsDocumentReferenceInCreateModel)
                return
            }
            
            let ref: DocumentReference
            
            if let superParentUid = superParentUid, let superParentType = Model.parentModelType as? SubCollectionModel.Type {
                let superCollectionName = superParentType.parentModelType.collectionName
                let parentCollectionName = Model.parentModelType.collectionName
                let collectionName = Model.collectionName
                ref = firestore.collection(superCollectionName).document(superParentUid)
                    .collection(parentCollectionName)
                    .document(parentUid)
                    .collection(collectionName)
                    .document()
            } else {
                ref = firestore.collection(Model.parentModelType.collectionName).document(parentUid)
                    .collection(Model.collectionName)
                    .document()
            }
            
            if model.updatedAt != nil || model.createdAt != nil {
                failure(FirestoreClientError.occureTimestampExceptionInCreateModel)
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
            guard let ref = model.ref else {
                failure(FirestoreClientError.notExistsDocumentReferenceInUpdateModel)
                return
            }
            
            if model.updatedAt == nil || model.createdAt == nil {
                failure(FirestoreClientError.occureTimestampExceptionInCreateModel)
                return
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
        filter: [FirestoreFilterModel],
        includeCache: Bool = true,
        order: [FirestoreOrderModel],
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
            let documents = snapshots.documents
            do {
                let models = try documents.map { document -> Model in
                    guard let model = try document.data(as: Model.self) else {
                        throw FirestoreClientError.failedToDecode(data: document.data())
                    }
                    return model
                }
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
                guard let model = try snapshot.data(as: Model.self) else {
                    throw FirestoreClientError.failedToDecode(data: snapshot.data())
                }
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
        let listener = firestore.collection(Model.parentModelType.collectionName).document(parentUID).collection(Model.collectionName).document(uid).addSnapshotListener { (snapshot, error) in
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
                guard let model = try snapshot.data(as: Model.self) else {
                    throw FirestoreClientError.failedToDecode(data: snapshot.data())
                }
                success(model)
            } catch {
                failure(error)
            }
        }
        listeners[Model.singleIdentifier]?.remove()
        listeners[Model.singleIdentifier] = listener
    }
    
    public func listen<Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        superParent superParentUid: String?,
        filter: [FirestoreFilterModel],
        includeCache: Bool = true,
        order: [FirestoreOrderModel],
        limit: Int?,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        let listener = createQueryOfSubCollection(
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
            let documents = snapshots.documents
            do {
                let models = try documents.map { document -> Model in
                    guard let model = try document.data(as: Model.self) else {
                        throw FirestoreClientError.failedToDecode(data: document.data())
                    }
                    return model
                }
                success(models)
            } catch {
                failure(error)
            }
        }
        listeners[Model.arrayIdentifier]?.remove()
        listeners[Model.arrayIdentifier] = listener
    }
    
    private func createQueryOfSubCollection
    <Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        superParent superParentUid: String?,
        modelType: Model.Type,
        filter: [FirestoreFilterModel]
    ) -> Query {
        var query: Query
        if let superParentUid = superParentUid,
           let superParentType = Model.parentModelType as? SubCollectionModel.Type {
            let superCollectionName = superParentType.parentModelType.collectionName
            let parentCollectionName = Model.parentModelType.collectionName
            let collectionName = Model.collectionName
            query = firestore.collection(superCollectionName).document(superParentUid).collection(parentCollectionName).document(parentUid).collection(collectionName)
        } else {
            query = firestore.collection(modelType.parentModelType.collectionName).document(parentUid).collection(modelType.collectionName)
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
        filter: FirestoreFilterModel,
        includeCache: Bool,
        order: [FirestoreOrderModel],
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
            let documents = snapshots.documents
            do {
                let models = try documents.map { document -> Model in
                    guard let model = try document.data(as: Model.self) else {
                        throw FirestoreClientError.failedToDecode(data: document.data())
                    }
                    return model
                }
                success(models)
            } catch {
                failure(error)
            }
        }
    }
    
    public func listenCollectionGroup<Model: FirestoreModel>(
        collectionName: String,
        filter: FirestoreFilterModel,
        includeCache: Bool,
        order: [FirestoreOrderModel],
        limit: Int?,
        success: @escaping ([Model]) -> Void,
        failure: @escaping (Error) -> Void
    ) {
        
        createQuery(
            from: firestore.collectionGroup(collectionName),
            filter: [filter]
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
            let documents = snapshots.documents
            do {
                let models = try documents.map { document -> Model in
                    guard let model = try document.data(as: Model.self) else {
                        throw FirestoreClientError.failedToDecode(data: document.data())
                    }
                    return model
                }
                success(models)
            } catch {
                failure(error)
            }
        }
    }
    
    private func createQuery(from ref: Query, filter: [FirestoreFilterModel]) -> Query {
        var query: Query = ref
        for element in filter {
            query = element.build(from: query)
        }
        return query
    }
}

// MARK: Order
extension Query {
    func build(order: [FirestoreOrderModel], limit: Int?) -> Query {
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
