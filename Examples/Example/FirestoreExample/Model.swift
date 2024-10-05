//
//  Model.swift
//  Example
//
//  Created by Fumiya Tanaka on 2022/01/01.
//

import EasyFirebaseSwiftFirestore
import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation

struct Model: FirestoreModel {

    static var collectionName: String = "models"

    @DocumentID
    var ref: DocumentReference?

    @ServerTimestamp
    var createdAt: Timestamp?

    @ServerTimestamp
    var updatedAt: Timestamp?

    var message: String
}
