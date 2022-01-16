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
        public let contentType: ContentType

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
    ) -> AnyPublisher<Resource.Task, Error> {
        let subject: CurrentValueSubject<Resource.Task, Error> = .init(
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
                metadata: storageMetadata) { metadata, error in
                    if let error = error {
                        subject.send(completion: .failure(error))
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
            subject.send(completion: .failure(error))
        }
        return subject.eraseToAnyPublisher()
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
