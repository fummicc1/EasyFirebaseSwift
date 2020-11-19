//
//  EasyFirebaseFirestoreSwift.swift
//  EasyFirebaseFirestoreSwift
//
//  Created by Fumiya Tanaka on 2020/11/19.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

public protocol FirestoreModel: Codable, Hashable {
    static var collectionName: String { get }
    var ref: DocumentReference? { get }
}

public protocol SubCollectionModel {
    static var parentCollectionName: String { get }
}

public protocol FirestoreFilterModel {
    func buildQuery(from ref: Query) -> Query
}

public struct FirestoreFilterEqualModel: FirestoreFilterModel {
    public var fieldPath: String
    public var value: Any
    
    public func buildQuery(from ref: Query) -> Query {
        ref.whereField(fieldPath, isEqualTo: value)
    }
}

public enum FirestoreClientError: Error {
    case failedToDecode
}

public class FirestoreClient {
    
    private let firestore = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    public func write<Model: FirestoreModel>(_ model: Model, merge: Bool, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        do {
            let ref: DocumentReference
            if let modelRef = model.ref {
                ref = modelRef
            } else {
                ref = firestore.collection(Model.collectionName).document()
            }
            try ref.setData(from: model, merge: merge) { (error) in
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
    
    public func listen<Model: FirestoreModel>(filter: [FirestoreFilterEqualModel], includeCache: Bool = false, success: @escaping ([Model]) -> Void, failure: @escaping (Error) -> Void) {
        let listener = createQuery(modelType: Model.self, filter: filter).addSnapshotListener(includeMetadataChanges: false) { (snapshots, error) in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshots = snapshots else {
                return
            }
            if snapshots.metadata.hasPendingWrites {
                return
            }
            if snapshots.metadata.isFromCache, includeCache == false {
                return
            }
            let documents = snapshots.documents
            do {
                let models = try documents.map { document -> Model in
                    guard let model = try document.data(as: Model.self) else {
                        throw FirestoreClientError.failedToDecode
                    }
                    return model
                }
                success(models)
            } catch {
                failure(error)
            }
        }
        listeners[Model.collectionName]?.remove()
        listeners[Model.collectionName] = listener
    }
    
    public func get<Model: FirestoreModel>(filter: [FirestoreFilterEqualModel], includeCache: Bool = false, success: @escaping ([Model]) -> Void, failure: @escaping (Error) -> Void) {
        createQuery(modelType: Model.self, filter: filter).getDocuments { (snapshots, error) in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshots = snapshots else {
                return
            }
            if snapshots.metadata.hasPendingWrites {
                return
            }
            if snapshots.metadata.isFromCache, includeCache == false {
                return
            }
            let documents = snapshots.documents
            do {
                let models = try documents.map { document -> Model in
                    guard let model = try document.data(as: Model.self) else {
                        throw FirestoreClientError.failedToDecode
                    }
                    return model
                }
                success(models)
            } catch {
                failure(error)
            }
        }
    }
    
    public func delete<Model: FirestoreModel>(_ model: Model, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
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
    
    private func createQuery<Model: FirestoreModel>(modelType: Model.Type, filter: [FirestoreFilterModel]) -> Query {
        var query: Query = firestore.collection(modelType.collectionName)
        for element in filter {
            query = element.buildQuery(from: query)
        }
        return query
    }
    
    public func stopListening<Model: FirestoreModel>(type: Model.Type) {
        listeners[Model.collectionName]?.remove()
    }
    
    public func delete<Model: FirestoreModel>(id: String, type: Model.Type, completion: ((Error?) -> Void)? = nil) {
        firestore.collection(Model.collectionName).document(id).delete(completion: completion)
    }
}

// MARK: SubCollection
extension FirestoreClient {
    public func write<Model: FirestoreModel & SubCollectionModel>(_ model: Model, parent parentUid: String, merge: Bool, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        do {
            let ref: DocumentReference
            if let modelRef = model.ref {
                ref = modelRef
            } else {
                ref = firestore.collection(Model.parentCollectionName).document(parentUid).collection(Model.collectionName).document()
            }
            try ref.setData(from: model, merge: merge) { (error) in
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
    
    public func get<Model: FirestoreModel & SubCollectionModel>(parent parentUid: String, filter: [FirestoreFilterEqualModel], includeCache: Bool = false, success: @escaping ([Model]) -> Void, failure: @escaping (Error) -> Void) {
        createQueryOfSubCollection(parent: parentUid, modelType: Model.self, filter: filter).addSnapshotListener(includeMetadataChanges: false) { (snapshots, error) in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshots = snapshots else {
                return
            }
            if snapshots.metadata.hasPendingWrites {
                return
            }
            if snapshots.metadata.isFromCache, includeCache == false {
                return
            }
            let documents = snapshots.documents
            do {
                let models = try documents.map { document -> Model in
                    guard let model = try document.data(as: Model.self) else {
                        throw FirestoreClientError.failedToDecode
                    }
                    return model
                }
                success(models)
            } catch {
                failure(error)
            }
        }
    }
    
    public func listen<Model: FirestoreModel & SubCollectionModel>(parent parentUid: String, filter: [FirestoreFilterEqualModel], includeCache: Bool = false, success: @escaping ([Model]) -> Void, failure: @escaping (Error) -> Void) {
        let listener = createQueryOfSubCollection(parent: parentUid, modelType: Model.self, filter: filter).addSnapshotListener(includeMetadataChanges: false) { (snapshots, error) in
            if let error = error {
                failure(error)
                return
            }
            guard let snapshots = snapshots else {
                return
            }
            if snapshots.metadata.hasPendingWrites {
                return
            }
            if snapshots.metadata.isFromCache, includeCache == false {
                return
            }
            let documents = snapshots.documents
            do {
                let models = try documents.map { document -> Model in
                    guard let model = try document.data(as: Model.self) else {
                        throw FirestoreClientError.failedToDecode
                    }
                    return model
                }
                success(models)
            } catch {
                failure(error)
            }
        }
        listeners[Model.collectionName]?.remove()
        listeners[Model.collectionName] = listener
    }
    
    private func createQueryOfSubCollection<Model: FirestoreModel & SubCollectionModel>(parent parentUid: String, modelType: Model.Type, filter: [FirestoreFilterModel]) -> Query {
        var query: Query = firestore.collection(modelType.parentCollectionName).document(parentUid).collection(modelType.collectionName)
        for element in filter {
            query = element.buildQuery(from: query)
        }
        return query
    }
}
