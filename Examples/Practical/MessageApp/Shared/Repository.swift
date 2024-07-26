//
//  Repository.swift
//  MessageApp
//
//  Created by Fumiya Tanaka on 2022/04/21.
//

import Foundation
import Combine
import EasyFirebaseSwiftFirestore
import EasyFirebaseSwiftStorage
import EasyFirebaseSwiftAuth

/// `Repository` has responsibility to store and handle all of contents in this app.
protocol Repository {

    // MARK: Message
    var messages: AnyPublisher<[Message], Never> { get }

    func saveMessage(_ message: Message) async throws
    func fetchMessages(of userID: String) async throws -> [Message]
    func deleteMessage(_ message: Message) async throws
    func updateMessage(message: Message) async throws

    // MARK: Auth
    var isLoggedIn: AnyPublisher<Bool, Never> { get }
    func signIn() async throws
    func signOut() async throws

    // MARK: User
    var uid: AnyPublisher<String, Never> { get }
    func fetchAvatar() -> AnyPublisher<Resource.Task, Never>
    func setupAvatar(of userID: String, image: Data) -> AnyPublisher<Resource.Task, Never>
}

class RepositoryImpl: ObservableObject, Repository {

    // MARK: EasyFirebaseSwift
    private let firestore: FirestoreClient = FirestoreClient()
    private let storage: StorageClient = StorageClient.shared
    private let auth: FirebaseAuthClient = FirebaseAuthClient()
    private let appleAuth: AppleAuthClient = AppleAuthClient()

    /// Sort documents with `postedAt`.
    private let order = DefaultFirestoreQueryOrder(
        fieldPath: "postedAt",
        isAscending: false
    )
    /// `avatars` Folder in FirebaseStrorage
    private let folder: HomeFolder = {
        var folder = HomeFolder()
        folder.name = "avatars"
        return folder
    }()

    // MARK: - Protocol Confirmance

    // MARK: Message
    var messages: AnyPublisher<[Message], Never> {
        // Create param, `SnapshotInputParameter.Default`.
        let param: SnapshotInputParameter.Default = .init(
            filter: [],
            order: [order],
            limit: nil
        )
        return Message.multiple(
            for: .snapshots(param)
        )
        .replaceError(with: [])
        .eraseToAnyPublisher()
    }

    func saveMessage(_ message: Message) async throws {
        _ = try await firestore.create(message)
    }

    func fetchMessages(of userID: String) async throws -> [Message] {
        // Create Filter
        let filter = FirestoreEqualFilter(
            fieldPath: "senderID",
            value: userID
        )
        // Call `get` method
        let messages: [Message] = try await firestore.get(
            filter: [filter],
            includeCache: true,
            order: [order],
            limit: nil
        )
        return messages
    }

    func deleteMessage(_ message: Message) async throws {
        try await firestore.delete(message)
    }

    func updateMessage(message: Message) async throws {
        try await firestore.update(message)
    }


    // MARK: Auth
    var isLoggedIn: AnyPublisher<Bool, Never> {
        auth.user
            .map({ $0 != nil })
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }

    // Mapping Combine to async/await
    func signIn() async throws {
        var iterator = auth.signInAnonymously()
            .values
            .makeAsyncIterator()
        _ = try await iterator.next()
    }

    func signOut() async throws {
        var iterator = auth.signOut()
            .values
            .makeAsyncIterator()
        _ = try await iterator.next()
    }

    // MARK: User
    var uid: AnyPublisher<String, Never> {
        auth.user
            .map({ $0?.uid ?? "" })
            .replaceError(with: "")
            .eraseToAnyPublisher()
    }
    func fetchAvatar() -> AnyPublisher<Resource.Task, Never> {
        let uid = auth.uid ?? ""
        let resource = Resource(
            name: uid,
            folder: folder,
            metadata: .init(contentType: .jpeg),
            data: nil
        )
        return resource.download()
    }

    func setupAvatar(of userID: String, image: Data) -> AnyPublisher<Resource.Task, Never> {
        let resource = Resource(
            name: userID,
            folder: folder,
            metadata: .init(contentType: .jpeg),
            data: image
        )
        return resource.uploadViaFile()
    }
}
