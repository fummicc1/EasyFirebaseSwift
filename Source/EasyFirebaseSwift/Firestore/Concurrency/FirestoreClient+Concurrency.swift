//
//  FirestoreClient+Concurrency.swift
//  FirestoreClient+Concurrency
//
//  Created by Fumiya Tanaka on 2021/09/04.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift


// MARK: async/await functions
@available(iOS 15, *)
@available(macOS 12, *)
public extension FirestoreClient {
    
    func writeTransaction<Model: FirestoreModel, FieldValue>(
        _ model: Model,
        fieldPath: WritableKeyPath<Model, FieldValue>,
        fieldValue: FieldValue,
        handler: @escaping ((FieldValue, FieldValue) -> FieldValue)
    ) async throws -> DocumentReference {
        let reference = try await withCheckedThrowingContinuation { continuation in
            self.writeTransaction(
                model,
                fieldPath: fieldPath,
                fieldValue: fieldValue,
                handler: handler,
                success: { reference in
                    continuation.resume(returning: reference)
                },
                failure: { error in
                    continuation.resume(throwing: error)
                })
        }
        return reference
    }
    
    func create<Model: FirestoreModel>(
        _ model: Model,
        documentId: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation({ continuation in
            create(
                model,
                documentId: documentId) { _ in
                    continuation.resume()
                } failure: { error in
                    continuation.resume(throwing: error)
                }
        })
    }

    /// Update document's data or Create new document if `model.ref` is nil.
    func write<Model: FirestoreModel>(
        _ model: Model,
        documentId: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation({ continuation in
            write(
                model,
                documentId: documentId) {
                    continuation.resume()
                } failure: { error in
                    continuation.resume(throwing: error)
                }
        })
    }

    func update<Model: FirestoreModel>(
        _ model: Model
    ) async throws {
        try await withCheckedThrowingContinuation({ continuation in
            update(model) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error)
            }
        })
    }

    func get<Model: FirestoreModel>(
        uid: String,
        includeCache: Bool = true
    ) async throws -> Model {
        let model = try await withCheckedThrowingContinuation({ continuation in
            self.get(
                uid: uid,
                includeCache: includeCache) { (model: Model) in
                    continuation.resume(returning: model)
                } failure: { error in
                    continuation.resume(throwing: error)
                }
        })
        return model
    }


    func get<Model: FirestoreModel>(
        filter: [FirestoreQueryFilter],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async throws -> [Model] {
        let models: [Model] = try await withCheckedThrowingContinuation({ continuation in
            get(
                filter: filter,
                includeCache: includeCache,
                order: order,
                limit: limit
            ) { models in
                continuation.resume(returning: models)
            } failure: { error in
                continuation.resume(throwing: error)
            }
        })
        return models
    }

    func delete<Model: FirestoreModel>(_ model: Model) async throws {
        try await withCheckedThrowingContinuation({ continuation in
            delete(model) {
                continuation.resume(returning: ())
            } failure: { error in
                continuation.resume(throwing: error)
            }
        })
    }

    func delete<Model: FirestoreModel>(
        id: String,
        type: Model.Type
    ) async throws {
        let _: Void = try await withCheckedThrowingContinuation({ continuation in
            delete(id: id, type: type) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        })
    }
}

// MARK: SubCollection
public extension FirestoreClient {

    func create<Model: FirestoreModel & SubCollectionModel>(
        _ model: Model,
        documentId: String? = nil,
        parent parentUid: String,
        superParent superParentUid: String?
    ) async throws -> DocumentReference {
        let ref: DocumentReference = try await withCheckedThrowingContinuation { continuation in
            create(
                model,
                documentId: documentId,
                parent: parentUid,
                superParent: superParentUid) { ref in
                    continuation.resume(returning: ref)
                } failure: { error in
                    continuation.resume(throwing: error)
                }
        }
        return ref
    }

    func update<Model: FirestoreModel & SubCollectionModel>(
        _ model: Model,
        parent parentUid: String,
        superParent superParentUid: String?
    ) async throws {
        let _: Void = try await withCheckedThrowingContinuation { continuation in
           update(
            model,
            parent: parentUid,
            superParent: superParentUid) {
                continuation.resume(returning: ())
            } failure: { error in
                continuation.resume(throwing: error)
            }
        }
    }

    func get<Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        superParent superParentUid: String?,
        filter: [FirestoreQueryFilter],
        includeCache: Bool = true,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async throws -> [Model] {
        let models: [Model] = try await withCheckedThrowingContinuation { continuation in
            get(
                parent: parentUid,
                superParent: superParentUid,
                filter: filter,
                includeCache: includeCache,
                order: order,
                limit: limit
            ) { models in
                continuation.resume(returning: models)
            } failure: { error in
                continuation.resume(throwing: error)
            }
        }
        return models
    }

    func get<Model: FirestoreModel & SubCollectionModel>(
        parent parentUid: String,
        superParent superParentUid: String?,
        docId: String,
        includeCache: Bool = true
    ) async throws -> Model {
        let model: Model = try await withCheckedThrowingContinuation { continuation in
            get(
                parent: parentUid,
                superParent: superParentUid,
                docId: docId) { model in
                    continuation.resume(returning: model)
                } failure: { error in
                    continuation.resume(throwing: error)
                }
        }
        return model
    }
}


// MARK: CollectionGroup
public extension FirestoreClient {
    public func getCollectionGroup<Model: FirestoreModel>(
        collectionName: String,
        filter: FirestoreQueryFilter,
        includeCache: Bool,
        order: [FirestoreQueryOrder],
        limit: Int?
    ) async throws -> [Model] {
        let models: [Model] = try await withCheckedThrowingContinuation({ continuation in
            getCollectionGroup(
                collectionName: collectionName,
                filter: filter,
                includeCache: includeCache,
                order: order,
                limit: limit) { models in
                    continuation.resume(returning: models)
                } failure: { error in
                    continuation.resume(throwing: error)
                }
        })
        return models
    }
}
