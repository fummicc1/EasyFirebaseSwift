//
//  ViewController+Async.swift
//  Example
//
//  Created by Fumiya Tanaka on 2022/01/01.
//

import Foundation
import FirebaseFirestore

extension ViewController {
    func create_async(message: String) async throws {
        let newModel = Model(
            ref: Model.generateDocumentReference(
                firestore: Firestore.firestore(),
                id: savedDocumentId
            ),
            createdAt: nil,
            updatedAt: nil,
            message: message
        )
        try await client.write(newModel)
    }
}
