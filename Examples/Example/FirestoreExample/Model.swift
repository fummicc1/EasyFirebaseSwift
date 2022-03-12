//
//  Model.swift
//  Example
//
//  Created by Fumiya Tanaka on 2022/01/01.
//

import Foundation
import FirebaseFirestore
import EasyFirebaseSwiftFirestore
import FirebaseFirestoreSwift

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
