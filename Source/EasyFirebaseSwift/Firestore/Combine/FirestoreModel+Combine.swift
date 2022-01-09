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

public enum FirestoreModelTypeAction<Model: FirestoreModel> {
    case snapshot(ref: DocumentReference)
    case snapshots(query: Query)
    case snapshots((filter: [FirestoreQueryFilter], order: [FirestoreQueryOrder], limit: Int?))
    case fetch(ref: DocumentReference)
    case query(query: Query)
}

public extension CombineCompatible where Self: FirestoreModel {
    func publisher(for action: FirestoreModelAction<Self>) -> FirestoreModelCombine.WritePublisher<Self> {
        FirestoreModelCombine.WritePublisher(model: self, action: action)
    }
    
    static func publisher(for action: FirestoreModelTypeAction<Self>) -> FirestoreModelCombine.FetchPublisher<Self> {
        FirestoreModelCombine.FetchPublisher(action: action)
    }
}
