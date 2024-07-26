//
//  Message.swift
//  MessageApp
//
//  Created by Fumiya Tanaka on 2022/04/21.
//

import Foundation
import FirebaseFirestoreSwift
import FirebaseFirestore
import EasyFirebaseSwiftFirestore

struct Message: FirestoreModel {

    // MARK: Protocol confirmance
    static var collectionName: String = "messages"

    @DocumentID
    var ref: DocumentReference?

    @ServerTimestamp
    var createdAt: Timestamp?

    @ServerTimestamp
    var updatedAt: Timestamp?

    // MARK: Custom Properties
    var text: String

    var postedAt: Timestamp?
    var senderID: String
    var receiverID: String? // if nil is assigned, will be broadcast.
}
