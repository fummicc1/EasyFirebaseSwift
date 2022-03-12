//
//  StorageClient.swift
//  
//
//  Created by Fumiya Tanaka on 2022/01/15.
//

import Combine
import Foundation
import FirebaseStorage

public protocol Folder {
    var name: String { get set }
    var reference: StorageReference { get }
}

public struct HomeFolder: Folder {
    public var name: String
    public var reference: StorageReference

    public init() {
        self.name = ""
        reference = StorageClient.shared.storage.reference()
    }
}

public struct RootFolder: Folder {
    public var name: String
    public var reference: StorageReference

    public init(name: String) {
        self.name = name
        reference = StorageClient.shared.storage.reference().child(name)
    }
}

public struct SubFolder: Folder {
    public var name: String
    public var reference: StorageReference

    public init(name: String, parent: StorageReference) {
        self.name = name
        reference = parent.child(name)
    }
}

public class Resource {
    public var name: String
    public var folder: Folder
    public var metadata: Metadata?
    public var data: Data?

    public init(
        name: String,
        folder: Folder,
        metadata: Metadata?,
        data: Data?
    ) {
        self.name = name
        self.folder = folder
        self.metadata = metadata
        self.data = data
    }

    public func reference() -> StorageReference {
        let format = metadata?.contentType.format ?? ""
        return folder.reference.child(name + "." + format)
    }

    public func upload(generateFile: Bool = false) -> AnyPublisher<Resource.Task, Never> {
        if generateFile {
            return uploadViaFile()
        }
        return uploadWithData()
    }

    public func uploadViaFile() -> AnyPublisher<Task, Never> {
        let subject: CurrentValueSubject<Task, Never> = .init(
            .init(
                status: .progress(0),
                resource: self
            )
        )
        do {
            let url = try generateFileURL(resource: self)
            let base = folder.reference.child(name)
            let storageMetadata = StorageMetadata()
            storageMetadata.contentType = metadata?.contentType.rawValue ?? ""
            let task = base.putFile(
                from: url,
                metadata: storageMetadata
            ) { metadata, error in
                if let error = error {
                    subject.send(
                        .init(
                            status: .fail(error),
                            resource: self
                        )
                    )
                    return
                }
                subject.send(completion: .finished)
            }
            StorageClient.shared.uploads.append(task)
            task.observe(.progress) { snapshot in
                let task: Resource.Task
                if let completedRate = snapshot.progress?.fractionCompleted {
                    if completedRate != 1 {
                        task = Resource.Task(
                            status: .progress(completedRate),
                            resource: self
                        )
                    } else {
                        task = Resource.Task(
                            status: .success,
                            resource: self
                        )
                    }
                    subject.send(task)
                }
            }
        } catch {
            subject.send(
                .init(
                    status: .fail(error),
                    resource: self
                )
            )
        }
        return subject.eraseToAnyPublisher()
    }

    func uploadWithData() -> AnyPublisher<Task, Never> {
        let subject: CurrentValueSubject<Task, Never> = .init(
            .init(
                status: .progress(0),
                resource: self
            )
        )
        guard let data = data else {
            assertionFailure("Resource has no data.")
            return Just(
                Resource.Task(
                    status: .fail(StorageClientError.noResourceData),
                    resource: self
                )
            ).eraseToAnyPublisher()
        }
        let storageMetadata = StorageMetadata()
        storageMetadata.contentType = metadata?.contentType.rawValue ?? ""
        let ref = folder.reference.child(name)
        let task = ref.putData(data, metadata: storageMetadata) { (_, error) in
            if let error = error {
                subject.send(
                    .init(
                        status: .fail(error),
                        resource: self
                    )
                )
                return
            }
            subject.send(completion: .finished)
        }
        StorageClient.shared.uploads.append(task)
        task.observe(.progress) { snapshot in
            if let completedRate = snapshot.progress?.fractionCompleted {
                let task: Resource.Task
                if completedRate != 1 {
                    task = Resource.Task(
                        status: .progress(completedRate),
                        resource: self
                    )
                } else {
                    task = Resource.Task(
                        status: .success,
                        resource: self
                    )
                }
                subject.send(task)
            }
        }
        return subject.eraseToAnyPublisher()
    }

    public func download(
        maxSize: Int64 = 1024 * 1024 * 10 // 10MB
    ) -> AnyPublisher<Task, Never> {
        let subject: CurrentValueSubject<Task, Never> = .init(
            .init(
                status: .progress(0),
                resource: self
            )
        )
        let target = reference()
        let storageTask = target.getData(
            maxSize: maxSize
        ) { data, error in
            if let error = error {
                subject.send(
                    .init(
                        status: .fail(error),
                        resource: self
                    )
                )
                return
            }
            self.data = data
            subject.send(
                .init(
                    status: .success,
                    resource: self
                )
            )
        }
        storageTask.observe(.progress) { snapshot in
            if let completeRate = snapshot.progress?.fractionCompleted {
                let task = Resource.Task(
                    status: .progress(completeRate),
                    resource: self
                )
                subject.send(task)
            }
        }
        return subject.eraseToAnyPublisher()
    }

    public func fetchDownloadURL() -> AnyPublisher<URL, Error> {
        Future { [weak self] promise in
            self?.reference().downloadURL { url, error in
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

    public func delete() -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            self?.reference().delete { error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }
}

public extension Resource {

    struct Metadata {
        public init(contentType: Resource.Metadata.ContentType) {
            self.contentType = contentType
        }

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
        public init(
            status: Resource.Status,
            resource: Resource
        ) {
            self.status = status
            self.resource = resource
        }

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
    case noResourceData
}

public class StorageClient {
    public var storage: Storage!
    var uploads: [StorageUploadTask] = []

    public static let shared: StorageClient = StorageClient()

    private init() { }

    public func cancel() {
        uploads.forEach { task in
            task.cancel()
        }
    }
}

func generateFileURL(resource: Resource) throws -> URL {
    // Generate file-url.
    let base: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    guard let base = base else {
        throw StorageClientError.failedToGenerateFile
    }
    let uuid: String = String(UUID().uuidString.prefix(8))
    let fileName = uuid
    let format = resource.metadata?.contentType.format
    var path = fileName
    if let format = format {
        path = fileName + "." + format
    }
    let target = base.appendingPathComponent(path)

    // Write data to file.
    try resource.data?.write(to: target)

    print(target.absoluteString)

    return target
}
