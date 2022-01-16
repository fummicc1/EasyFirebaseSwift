//
//  StorageClient.swift
//  
//
//  Created by Fumiya Tanaka on 2022/01/15.
//

import Combine
import Foundation
import FirebaseStorage

public class Folder {
    public let name: String
    public let resources: [Resource]
    public let reference: StorageReference

    public init(
        name: String,
        parent: StorageReference = Storage.storage().reference(),
        resources: [Resource] = []
    ) {
        self.name = name
        self.resources = resources
        self.reference = parent.child(name)
    }
}

public class Resource {
    public var name: String
    public var metadata: Metadata?
    public var data: Data?

    public init(
        name: String,
        metadata: Metadata?,
        data: Data?
    ) {
        self.name = name
        self.metadata = metadata
        self.data = data
    }

    public func reference(from parent: Folder) -> StorageReference {
        let format = metadata?.contentType.format ?? ""
        return parent.reference.child(name + "." + format)
    }
}

public extension Resource {

    struct Metadata {
        public var contentType: ContentType

        public enum ContentType: String {
            case plain = "text/plain"
            case csv = "text/csv"
            case html = "text/html"
            case css = "text/css"
            case json = "application/json"
            case jpeg = "image/jpeg"
            case png = "image/png"
            case mp3 = "audio/mpeg"
            case mp4 = "video/mp4"
            case mpeg = "video/mpeg"

            public var format: String {
                switch self {
                case .plain:
                    return "txt"
                case .csv:
                    return "csv"
                case .html:
                    return "html"
                case .css:
                    return "css"
                case .json:
                    return "json"
                case .jpeg:
                    return "jpeg"
                case .png:
                    return "png"
                case .mp3:
                    return "mp3"
                case .mp4:
                    return "mp4"
                case .mpeg:
                    return "mpeg"
                }
            }
        }
    }

    struct Task {
        public let status: Status
        public let resource: Resource
    }

    enum Status {
        case progress(Double)
        case success
        case fail(Error)
    }
}

public enum StorageClientError: Swift.Error {
    case failedToGenerateFile
}

public class StorageClient {
    private let storage: Storage

    public init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }

    public func upload(
        resource: Resource,
        folder: Folder,
        parent: StorageReference
    ) -> AnyPublisher<Resource.Task, Never> {
        let subject: CurrentValueSubject<Resource.Task, Never> = .init(
            .init(
                status: .progress(0),
                resource: resource
            )
        )
        do {
            let url = try generateFileURL(resource: resource)
            let base = folder.reference
            let storageMetadata = StorageMetadata()
            storageMetadata.contentType = resource.metadata?.contentType.rawValue ?? ""
            let progress = base.putFile(
                from: url,
                metadata: storageMetadata
            ) { metadata, error in
                if let error = error {
                    subject.send(.init(status: .fail(error), resource: resource))
                    return
                }
                subject.send(completion: .finished)
            }
            progress.observe(.progress) { snapshot in
                if let completedRate = snapshot.progress?.fractionCompleted {
                    let task = Resource.Task(
                        status: .progress(completedRate),
                        resource: resource
                    )
                    subject.send(task)
                }
            }
        } catch {
            subject.send(.init(status: .fail(error), resource: resource))
        }
        return subject.eraseToAnyPublisher()
    }

    public func download(
        resource: Resource,
        folder: Folder,
        maxSize: Int64 = 1024 * 1024 * 10 // 10MB
    ) -> AnyPublisher<Resource.Task, Never> {
        let subject: CurrentValueSubject<Resource.Task, Never> = .init(
            .init(
                status: .progress(0),
                resource: resource
            )
        )
        let target = resource.reference(from: folder)
        let storageTask = target.getData(
            maxSize: maxSize
        ) { data, error in
            if let error = error {
                subject.send(.init(status: .fail(error), resource: resource))
                return
            }
            resource.data = data
            subject.send(.init(status: .success, resource: resource))
        }
        storageTask.observe(.progress) { snapshot in
            if let completeRate = snapshot.progress?.fractionCompleted {
                let task = Resource.Task(
                    status: .progress(completeRate),
                    resource: resource
                )
                subject.send(task)
            }
        }
        return subject.eraseToAnyPublisher()
    }

    public func fetchDownloadURL(
        of resource: Resource,
        folder: Folder
    ) -> AnyPublisher<URL, Error> {
        Future { promise in
            let reference = resource.reference(from: folder)
            reference.downloadURL { url, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                if let url = url {
                    promise(.success(url))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    public func delete(
        resource: Resource,
        folder: Folder
    ) -> AnyPublisher<Void, Error> {
        Future { promise in
            resource.reference(from: folder).delete { error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }

    func generateFileURL(resource: Resource, isTemporary: Bool = true) throws -> URL {
        let base: URL?
        if isTemporary {
            base = FileManager.default.temporaryDirectory
        } else {
            base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        }
        guard let base = base else {
            throw StorageClientError.failedToGenerateFile
        }
        let uuid: String = UUID().uuidString
        let fileName = uuid
        let format = resource.metadata?.contentType.format ?? ""
        let path = fileName + "." + format
        let target = base.appendingPathComponent(path)
        return target
    }
}
