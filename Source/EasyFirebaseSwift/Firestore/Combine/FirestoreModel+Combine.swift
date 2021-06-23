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
    case update
    case delete
}

public enum FirestoreModelTypeAction<Model: FirestoreModel> {
    case snapshot(ref: DocumentReference)
    case snapshots(query: Query)
    case get(ref: DocumentReference)
    case gets(query: Query)
}

public extension CombineCompatible where Self: FirestoreModel {
    func publisher(for action: FirestoreModelAction<Self>) -> FirestoreModelCombine.WritePublisher<Self> {
        FirestoreModelCombine.WritePublisher(model: self, action: action)
    }
    
    static func publisher(for action: FirestoreModelTypeAction<Self>) -> FirestoreModelCombine.GetPublisher<Self> {
        FirestoreModelCombine.GetPublisher(action: action)
    }
}
