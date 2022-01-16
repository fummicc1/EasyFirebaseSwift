//
//  StorageClientTests.swift
//  
//
//  Created by Fumiya Tanaka on 2022/01/16.
//

import XCTest
import Combine
import FirebaseStorage
@testable import EasyFirebaseSwift

class StorageClientTests: XCTestCase {

    private var client: StorageClient!
    private var cancellables: Set<AnyCancellable> = []
    private let defaultStorage: Storage = Storage.storage(url: FirebaseTestHelper.gsBucket)

    override func setUpWithError() throws {
        FirebaseTestHelper.setupFirebaseApp()
        StorageClient.defaultStorage = defaultStorage
        client = StorageClient()
    }

    // TODO: Work TestCase
//    func test_upload() {
//        let folder = Folder(name: "Tests")
//        let text: String = "Test Test Test Test Text!!"
//        let data = text.data(using: .utf8)!
//        let resource = Resource(
//            name: "test",
//            metadata: Resource.Metadata(contentType: .plain),
//            data: data
//        )
//        let exp = XCTestExpectation(description: "Test")
//        client.upload(resource: resource, folder: folder)
//            .sink { task in
//                switch task.status {
//                case .success:
//                    exp.fulfill()
//                case .fail(let error):
//                    XCTFail(error.localizedDescription)
//                default:
//                    break
//                }
//            }
//            .store(in: &cancellables)
//        wait(for: [exp], timeout: 30)
//    }
}
