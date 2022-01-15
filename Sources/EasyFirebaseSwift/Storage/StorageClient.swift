//
//  StorageClient.swift
//  
//
//  Created by Fumiya Tanaka on 2022/01/15.
//

import Combine
import Foundation
import FirebaseStorage

public class Resource {
    public let name: String
    public let metadata: Metadata?
    public let data: Data?

    public init(
        name: String,
        metadata: Metadata?,
        data: Data?
    ) {
        self.name = name
        self.metadata = metadata
        self.data = data
    }
}

public extension Resource {

    struct Metadata {
        public let format: String
    }

    struct Result {
        public let status: Status
        public let resource: Resource
    }

    enum Status {
        case progress(Double)
        case success
        case fail(Error)
    }
}

public class StorageClient {
    private let storage: Storage

    public init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }

    public func upload(resource: Resource, parent: StorageReference) -> AnyPublisher<Resource.Result, Error> {
        fatalError()
    }
}
