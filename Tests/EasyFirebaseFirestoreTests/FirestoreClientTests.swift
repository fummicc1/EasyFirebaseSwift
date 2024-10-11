//
//  FirestoreClientTests.swift
//
//
//  Created by Fumiya Tanaka on 2022/01/16.
//

import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift
import XCTest

@testable import EasyFirebaseFirestore
@testable import TestCore

struct TestModel: FirestoreModel {

    // MARK: Protocol Requirement
    static let collectionName: String = "tests"
    @DocumentID
    var ref: DocumentReference?
    @ServerTimestamp
    var createdAt: Timestamp?
    @ServerTimestamp
    var updatedAt: Timestamp?

    // MARK: Custom Property
    var message: String
}

class FirestoreClientTests: XCTestCase {

    private var client: FirestoreClient!
    private var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        FirebaseTestHelper.setupFirebaseApp()
        client = FirestoreClient()
    }

    func test_create_async() async throws {
        let newModel = TestModel(message: "Async Test")
        let ref = try await client.write(newModel)
        let documentId = ref.documentID
        let fetched: TestModel = try await client.get(documentId: documentId)
        XCTAssertEqual(newModel.message, fetched.message)
    }
}
