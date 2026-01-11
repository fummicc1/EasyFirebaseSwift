//
//  MockFirestoreClientTests.swift
//
//  Created by EasyFirebaseSwift
//

import FirebaseFirestore
import XCTest

@testable import EasyFirebaseFirestore
@testable import TestCore

/// Test model for MockFirestoreClient tests
private struct MockTestModel: FirestoreModel, Equatable {
    static let collectionName: String = "mock_tests"
    @DocumentID var ref: DocumentReference?
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?

    var name: String
    var value: Int

    static func == (lhs: MockTestModel, rhs: MockTestModel) -> Bool {
        lhs.name == rhs.name && lhs.value == rhs.value
    }
}

final class MockFirestoreClientTests: XCTestCase {

    private var mockClient: MockFirestoreClient!

    override func setUp() {
        super.setUp()
        FirebaseTestHelper.setupFirebaseApp()
        mockClient = MockFirestoreClient()
    }

    override func tearDown() async throws {
        await mockClient.reset()
        mockClient = nil
        try await super.tearDown()
    }

    // MARK: - Write Tests

    func test_write_storesModel() async throws {
        // Arrange
        let model = MockTestModel(name: "Test", value: 42)

        // Act
        let ref = try await mockClient.write(model, newDocumentIdIfNotExists: "doc-1")

        // Assert
        XCTAssertEqual(ref.documentID, "doc-1")
        let stored = await mockClient.getAllStoredData(type: MockTestModel.self)
        XCTAssertEqual(stored["doc-1"]?.name, "Test")
        XCTAssertEqual(stored["doc-1"]?.value, 42)
    }

    func test_write_generatesIdWhenNil() async throws {
        // Arrange
        let model = MockTestModel(name: "Auto ID", value: 1)

        // Act
        let ref = try await mockClient.write(model)

        // Assert
        XCTAssertTrue(ref.documentID.hasPrefix("mock-doc-"))
    }

    func test_write_throwsInjectedError() async throws {
        // Arrange
        struct TestError: Error {}
        await mockClient.setNextError(TestError())
        let model = MockTestModel(name: "Test", value: 1)

        // Act & Assert
        do {
            _ = try await mockClient.write(model)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    // MARK: - Read Tests

    func test_get_returnsStoredModel() async throws {
        // Arrange
        let model = MockTestModel(name: "Stored", value: 100)
        await mockClient.setMockData(model, for: "doc-123")

        // Act
        let result: MockTestModel = try await mockClient.get(documentId: "doc-123")

        // Assert
        XCTAssertEqual(result.name, "Stored")
        XCTAssertEqual(result.value, 100)
    }

    func test_get_throwsNotFoundForMissingDocument() async throws {
        // Act & Assert
        do {
            let _: MockTestModel = try await mockClient.get(documentId: "nonexistent")
            XCTFail("Expected error to be thrown")
        } catch let error as EasyFirebaseFirestoreError {
            if case .notFound = error {
                // Expected
            } else {
                XCTFail("Expected notFound error, got \(error)")
            }
        }
    }

    func test_get_throwsInjectedError() async throws {
        // Arrange
        struct TestError: Error {}
        await mockClient.setNextError(TestError())
        await mockClient.setMockData(MockTestModel(name: "Test", value: 1), for: "doc-1")

        // Act & Assert
        do {
            let _: MockTestModel = try await mockClient.get(documentId: "doc-1")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func test_getMultiple_returnsAllModels() async throws {
        // Arrange
        await mockClient.setMockData(MockTestModel(name: "One", value: 1), for: "doc-1")
        await mockClient.setMockData(MockTestModel(name: "Two", value: 2), for: "doc-2")

        // Act
        let results: [MockTestModel] = try await mockClient.get()

        // Assert
        XCTAssertEqual(results.count, 2)
    }

    func test_getMultiple_respectsLimit() async throws {
        // Arrange
        await mockClient.setMockData(MockTestModel(name: "One", value: 1), for: "doc-1")
        await mockClient.setMockData(MockTestModel(name: "Two", value: 2), for: "doc-2")
        await mockClient.setMockData(MockTestModel(name: "Three", value: 3), for: "doc-3")

        // Act
        let results: [MockTestModel] = try await mockClient.get(filter: [], limit: 2)

        // Assert
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - Delete Tests

    func test_delete_removesModel() async throws {
        // Arrange
        var model = MockTestModel(name: "ToDelete", value: 1)
        let ref = try await mockClient.write(model, newDocumentIdIfNotExists: "doc-delete")
        model.ref = ref

        // Act
        try await mockClient.delete(model)

        // Assert
        let stored = await mockClient.getAllStoredData(type: MockTestModel.self)
        XCTAssertNil(stored["doc-delete"])
    }

    func test_delete_throwsRefNotExistsWhenNoRef() async throws {
        // Arrange
        let model = MockTestModel(name: "NoRef", value: 1)

        // Act & Assert
        do {
            try await mockClient.delete(model)
            XCTFail("Expected error to be thrown")
        } catch let error as EasyFirebaseFirestoreError {
            if case .refNotExists = error {
                // Expected
            } else {
                XCTFail("Expected refNotExists error, got \(error)")
            }
        }
    }

    // MARK: - Listener Tests

    func test_listen_emitsCurrentValue() async throws {
        // Arrange
        let model = MockTestModel(name: "Current", value: 50)
        await mockClient.setMockData(model, for: "doc-listen")

        // Act
        let stream: AsyncThrowingStream<MockTestModel, Error> = await mockClient.listen(documentId: "doc-listen")

        var receivedModels: [MockTestModel] = []
        for try await received in stream.prefix(1) {
            receivedModels.append(received)
        }

        // Assert
        XCTAssertEqual(receivedModels.count, 1)
        XCTAssertEqual(receivedModels[0].name, "Current")
        XCTAssertEqual(receivedModels[0].value, 50)
    }

    func test_emitToListener_sendsUpdate() async throws {
        // Arrange
        let initialModel = MockTestModel(name: "Initial", value: 1)
        await mockClient.setMockData(initialModel, for: "doc-emit")

        let stream: AsyncThrowingStream<MockTestModel, Error> = await mockClient.listen(documentId: "doc-emit")
        var iterator = stream.makeAsyncIterator()

        // Get initial value
        let first = try await iterator.next()
        XCTAssertEqual(first?.name, "Initial")

        // Act - emit update in background
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            let updated = MockTestModel(name: "Updated", value: 2)
            await mockClient.emitToListener(updated, for: "doc-emit")

            try await Task.sleep(nanoseconds: 100_000_000)
            await mockClient.finishListener(for: "doc-emit", type: MockTestModel.self)
        }

        // Assert
        let second = try await iterator.next()
        XCTAssertEqual(second?.name, "Updated")
        XCTAssertEqual(second?.value, 2)
    }

    // MARK: - Reset Tests

    func test_reset_clearsAllData() async throws {
        // Arrange
        await mockClient.setMockData(MockTestModel(name: "Test", value: 1), for: "doc-1")
        await mockClient.setNextError(NSError(domain: "test", code: 1))
        await mockClient.setSimulatedDelay(nanoseconds: 1000)

        // Act
        await mockClient.reset()

        // Assert
        let stored = await mockClient.getAllStoredData(type: MockTestModel.self)
        XCTAssertTrue(stored.isEmpty)
        let nextError = await mockClient.nextError
        XCTAssertNil(nextError)
        let delay = await mockClient.simulatedDelayNanoseconds
        XCTAssertNil(delay)
    }

    // MARK: - Delay Simulation Tests

    func test_simulatedDelay_addsLatency() async throws {
        // Arrange
        await mockClient.setMockData(MockTestModel(name: "Delayed", value: 1), for: "doc-1")
        await mockClient.setSimulatedDelay(nanoseconds: 100_000_000) // 0.1 seconds

        let start = Date()

        // Act
        let _: MockTestModel = try await mockClient.get(documentId: "doc-1")

        // Assert
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(elapsed, 0.09)
    }
}

// MARK: - Protocol Usage Example

/// Example demonstrating how to use FirestoreClientProtocol for dependency injection
private class ExampleRepository {
    private let client: any FirestoreClientProtocol

    init(client: any FirestoreClientProtocol) {
        self.client = client
    }

    func fetchItem(id: String) async throws -> MockTestModel {
        try await client.get(documentId: id)
    }

    func saveItem(_ item: MockTestModel) async throws {
        try await client.write(item)
    }
}

/// Tests demonstrating protocol-based dependency injection
final class ProtocolUsageExampleTests: XCTestCase {

    func test_repositoryWithMock() async throws {
        // Arrange
        FirebaseTestHelper.setupFirebaseApp()
        let mockClient = MockFirestoreClient()
        let repository = ExampleRepository(client: mockClient)

        let testItem = MockTestModel(name: "Item", value: 123)
        await mockClient.setMockData(testItem, for: "item-1")

        // Act
        let result = try await repository.fetchItem(id: "item-1")

        // Assert
        XCTAssertEqual(result.name, "Item")
        XCTAssertEqual(result.value, 123)
    }

    func test_repositoryWithMock_errorHandling() async throws {
        // Arrange
        FirebaseTestHelper.setupFirebaseApp()
        let mockClient = MockFirestoreClient()
        let repository = ExampleRepository(client: mockClient)

        struct CustomError: Error {}
        await mockClient.setNextError(CustomError())

        // Act & Assert
        do {
            _ = try await repository.fetchItem(id: "any")
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is CustomError)
        }
    }
}
