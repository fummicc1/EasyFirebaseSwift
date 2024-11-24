//
//  FirebaseAuthClient.swift
//
//
//  Created by Fumiya Tanaka on 2021/05/02.
//

import FirebaseAuth
import Foundation

public enum FirebaseAuthClientError: Error {
    case noAuthData
    case currentUserNotFound
    case noEmailToLink
}

public class FirebaseAuthClient {

    internal let auth: Auth

    public var uid: String? {
        auth.currentUser?.uid
    }

    public let continuation: AsyncStream<FirebaseAuth.User?>.Continuation
    public let stream: AsyncStream<FirebaseAuth.User?>

    public var currentUser: FirebaseAuth.User? {
        auth.currentUser
    }

    public init(
        auth: Auth = Auth.auth()
    ) {
        self.auth = auth
        let (stream, continuation) = AsyncStream<FirebaseAuth.User?>.makeStream()
        let listener = auth.addStateDidChangeListener { (_, user) in
            continuation.yield(user)
        }
        continuation.onTermination = { _ in
            auth.removeStateDidChangeListener(listener)
        }
        self.continuation = continuation
        self.stream = stream
    }

    public func signIn(
        with credential: AuthCredential
    ) async throws -> FirebaseAuth.User {
        let data = try await auth.signIn(with: credential)
        return data.user
    }

    internal func getAppleCredential(
        idToken token: String,
        nonce: String
    ) -> AuthCredential {
        let credential = OAuthProvider.credential(
            providerID: .apple,
            idToken: token,
            rawNonce: nonce
        )
        return credential
    }

    public func link(with credential: AuthCredential) async throws -> FirebaseAuth.User {
        guard let currentUser else {
            throw FirebaseAuthClientError.currentUserNotFound
        }
        let data = try await currentUser.link(with: credential)
        return data.user
    }

    public func signInWithApple(idToken token: String, nonce: String) async throws
        -> FirebaseAuth.User
    {
        let credential = getAppleCredential(idToken: token, nonce: nonce)
        return try await signIn(with: credential)
    }

    public func signInAnonymously() async throws -> FirebaseAuth.User {
        let data = try await auth.signInAnonymously()
        return data.user
    }

    public func signOut() async throws {
        try auth.signOut()
    }

    public func delete() async throws {
        try await auth.currentUser?.delete()
    }
}
