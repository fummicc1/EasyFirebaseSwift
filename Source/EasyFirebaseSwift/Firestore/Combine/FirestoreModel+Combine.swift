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
    case create(Model)
    case update(Model)
    case snapshot(DocumentReference)
    case snapshots
    case get(DocumentReference)
    case gets
    case delete(DocumentReference)
}

public extension CombineCompatible where Self: FirestoreModel {
    func publisher(for action: FirestoreModelAction<Self>) -> FirestoreModelCombine.Publisher<Self> {
        FirestoreModelCombine.Publisher(model: self, action: action)
    }
}
