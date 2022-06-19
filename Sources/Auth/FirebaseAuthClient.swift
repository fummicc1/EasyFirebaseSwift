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
    case noEmailToLink
}

public class FirebaseAuthClient {

    private let auth: Auth
    private let userSubject: CurrentValueSubject<FirebaseAuth.User?, Error> = .init(nil)
    
    public var uid: String? {
        auth.currentUser?.uid
    }
    
    public var currentUser: FirebaseAuth.User? {
        userSubject.value
    }
    
    public var user: AnyPublisher<FirebaseAuth.User?, Error> {
        userSubject.dropFirst().eraseToAnyPublisher()
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

    public func createUserWithEmailAndPassword(
        email: String,
        password: String,
        needVerification: Bool,
        actionCodeSettings: ActionCodeSettings?
    ) -> AnyPublisher<FirebaseAuth.User, Error> {
        Future { [weak self] promise in
            self?.auth.createUser(withEmail: email, password: password, completion: { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let result = result else {
                    promise(.failure(FirebaseAuthClientError.noAuthData))
                    return
                }
                guard needVerification else {
                    promise(.success(result.user))
                    return
                }
                // TODO: want to write a cleaner code
                if let actionCodeSettings = actionCodeSettings {
                    result.user.sendEmailVerification(with: actionCodeSettings) { error in
                        if let error = error {
                            promise(.failure(error))
                            return
                        }
                        promise(.success(result.user))
                    }
                } else {
                    result.user.sendEmailVerification { error in
                        if let error = error {
                            promise(.failure(error))
                            return
                        }
                        promise(.success(result.user))
                    }
                }
            })
        }.eraseToAnyPublisher()
    }

    public func sendSignInLink(
        email: String,
        actionCodeSettings: ActionCodeSettings,
        shouldSaveEmail: Bool = false
    ) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            self?.auth.sendSignInLink(
                toEmail: email,
                actionCodeSettings: actionCodeSettings
            ) { error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                if shouldSaveEmail {
                    let key = "EasyFirebaseSwift.sendSignInLink.Email"
                    UserDefaults.standard.set(email, forKey: key)
                }
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }

    public func signInWithLink(
        link: String,
        email: String?,
        shouldUseSavedEmail: Bool = false
    ) -> AnyPublisher<FirebaseAuth.User, Error> {
        Future { [weak self] promise in
            var email: String? = email
            if shouldUseSavedEmail {
                let key = "EasyFirebaseSwift.sendSignInLink.Email"
                email = UserDefaults.standard.object(forKey: key) as? String
            }
            guard let email = email else {
                promise(.failure(FirebaseAuthClientError.noEmailToLink))
                return
            }
            self?.auth.signIn(
                withEmail: email,
                link: link
            ) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let user = result?.user else {
                    promise(.failure(FirebaseAuthClientError.noAuthData))
                    return
                }
                promise(.success(user))
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
