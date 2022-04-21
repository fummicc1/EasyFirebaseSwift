//
//  FirestoreClientTests.swift
//  
//
//  Created by Fumiya Tanaka on 2022/01/16.
//

import XCTest
import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift
@testable import EasyFirebaseSwiftFirestore
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

    @available(iOS 15, *)
    @available(macOS 12, *)
    func test_create_async() async throws {
        let newModel = TestModel(message: "Async Test")
        let ref = try await client.create(newModel)
        let fetched: TestModel = try await client.get(uid: ref.documentID)
        XCTAssertEqual(newModel.message, fetched.message)
    }

    func test_create_combine() {
        let newModel = TestModel(message: "Combine Test")
        let exp = XCTestExpectation(description: "Test_Create_Combine")
        newModel.write(for: .create, client: client)
            .sink { completion in
                switch completion {
                case .finished:
                    exp.fulfill()
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)
    }
}
