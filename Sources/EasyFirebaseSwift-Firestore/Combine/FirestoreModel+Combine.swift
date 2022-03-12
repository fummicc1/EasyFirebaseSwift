//
//  FirestoreModel+Combine.swift
//  
//
//  Created by Fumiya Tanaka on 2021/05/03.
//

import Foundation
import FirebaseFirestore
import Combine

public protocol CombineCompatible { }

public enum FirestoreModelAction<Model: FirestoreModel> {
    case create
    case createWithDocumentId(String)
    case update
    case delete
}

public protocol SnapshotInputParameterType {
}

public enum SnapshotInputParameter {
    public struct Default: SnapshotInputParameterType {
        public init(
            filter: [FirestoreQueryFilter] = [],
            order: [FirestoreQueryOrder] = [],
            limit: Int? = nil
        ) {
            self.filter = filter
            self.order = order
            self.limit = limit
        }

        public let filter: [FirestoreQueryFilter]
        public let order: [FirestoreQueryOrder]
        public let limit: Int?
    }

    public struct Query: SnapshotInputParameterType {
        public init(
            ref: FirebaseFirestore.Query,
            includeCache: Bool = false
        ) {
            self.ref = ref
            self.includeCache = includeCache
        }

        public let ref: FirebaseFirestore.Query
        public let includeCache: Bool
    }
}

public enum FirestoreModelTypeAction<Model: FirestoreModel> {
    case snapshot(ref: DocumentReference)
    case snapshots(SnapshotInputParameterType)
    case fetch(ref: DocumentReference)
    case query(query: Query)
}

public extension CombineCompatible where Self: FirestoreModel {
    func write(
        for action: FirestoreModelAction<Self>,
        client: FirestoreClient = FirestoreClient()
    ) -> FirestoreModelCombine.WritePublisher<Self> {
        FirestoreModelCombine.WritePublisher(
            model: self,
            action: action,
            firestoreClient: client
        )
    }
    
    static func single(
        for action: FirestoreModelTypeAction<Self>,
        client: FirestoreClient = FirestoreClient()
    ) -> FirestoreModelCombine.FetchPublisher<Self> {
        FirestoreModelCombine.FetchPublisher(
            action: action,
            firestoreClient: client
        )
    }

    static func multiple(
        for action: FirestoreModelTypeAction<Self>,
        client: FirestoreClient = FirestoreClient()
    ) -> FirestoreModelCombine.CollectionPublisher<Self> {
        FirestoreModelCombine.CollectionPublisher(
            action: action,
            firestoreClient: client
        )
    }
}
