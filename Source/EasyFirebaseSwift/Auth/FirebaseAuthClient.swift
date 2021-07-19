//
//  FirebaseAuthClient.swift
//  
//
//  Created by Fumiya Tanaka on 2021/05/02.
//

import Foundation
import FirebaseAuth
import Combine

public enum FirebaseAuthClientError: Error {
    case noAuthData
    case failedToLinkDueToNoCurrentUser
}

public class FirebaseAuthClient {

    private let auth: Auth
    private let userSubject: CurrentValueSubject<FirebaseAuth.User?, Error> = .init(nil)
    
    public var uid: String? {
        auth.currentUser?.uid
    }
    
    public var user: AnyPublisher<FirebaseAuth.User?, Error> {
        userSubject.eraseToAnyPublisher()
    }

    public init(auth: Auth = Auth.auth()) {
        self.auth = auth

        auth.addStateDidChangeListener { [weak self] (_, user) in
            self?.userSubject.send(user)
        }
    }

    public func signIn(with credential: AuthCredential) -> AnyPublisher<FirebaseAuth.User, Error> {
        Future<FirebaseAuth.User, Error> { [weak self] promise in
            self?.auth.signIn(with: credential, completion: { (data, error) in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let data = data else {
                    promise(.failure(FirebaseAuthClientError.noAuthData))
                    return
                }
                promise(.success(data.user))
            })
        }.eraseToAnyPublisher()
    }
    
    public func getAppleCredential(idToken token: String, nonce: String?) -> AuthCredential {
        let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: token, rawNonce: nonce)
        return credential
    }
    
    public func link(with credential: AuthCredential) -> AnyPublisher<FirebaseAuth.User, Error> {
        Future<FirebaseAuth.User, Error> { [weak self] promise in
            guard let user = self?.auth.currentUser else {
                promise(.failure(FirebaseAuthClientError.failedToLinkDueToNoCurrentUser))
                return
            }
            user.link(with: credential, completion: { (result, error) in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                if let user = result?.user {
                    promise(.success(user))
                } else {
                    promise(.failure(FirebaseAuthClientError.noAuthData))
                }
            })
        }
        .eraseToAnyPublisher()
    }
    
    public func signInWithApple(idToken token: String, nonce: String?) -> AnyPublisher<FirebaseAuth.User, Error> {
        let credential = getAppleCredential(idToken: token, nonce: nonce)
        return signIn(with: credential)
    }
    
    public func signInAnonymously() -> AnyPublisher<FirebaseAuth.User, Error> {
        Future<FirebaseAuth.User, Error> { [weak self] promise in
            self?.auth.signInAnonymously { (result, error) in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                if let user = result?.user {
                    promise(.success(user))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    public func signOut() -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            do {
                try self?.auth.signOut()
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    public func delete() -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            self?.auth.currentUser?.delete(completion: { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            })
        }.eraseToAnyPublisher()
    }
}
