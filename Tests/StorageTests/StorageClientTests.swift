//
//  StorageClientTests.swift
//  
//
//  Created by Fumiya Tanaka on 2022/01/16.
//

import XCTest
import Combine
import FirebaseStorage
@testable import EasyFirebaseSwiftStorage

class StorageClientTests: XCTestCase {

    private var client: StorageClient!
    private var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        FirebaseTestHelper.setupFirebaseApp()
        let defaultStorage: Storage = Storage.storage(url: FirebaseTestHelper.gsBucket)
        StorageClient.defaultStorage = defaultStorage
        client = StorageClient()
    }

    // TODO: Work TestCase
    func test_upload_data() {
        let folder = Folder(name: "Tests")
        let text: String = "Test Test Test Test Text!!"
        let data = text.data(using: .utf8)!
        let resource = Resource(
            name: "test",
            metadata: Resource.Metadata(contentType: .plain),
            data: data
        )
        let exp = XCTestExpectation(description: "Test")
        client.uploadWithData(resource: resource, folder: folder)
            .sink { task in
                switch task.status {
                case .success:
                    exp.fulfill()
                case .fail(let error):
                    XCTFail(error.localizedDescription)
                    exp.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        wait(for: [exp], timeout: 30)
    }
}
