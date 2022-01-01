//
//  AppleAuthClient.swift
//  
//
//  Created by Fumiya Tanaka on 2021/05/02.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import Foundation
import Combine
import CryptoKit
import AuthenticationServices
import FirebaseAuth

public enum AppleAuthClientError: Error {
    case failedToCastCredential
    case emptyNonce
    case emptyIdToken
}


public class AppleAuthClient: NSObject {

    // Unhashed nonce.
    public private(set) var currentNonce: String?
    public weak var delegate: ASAuthorizationControllerDelegate?

    public func startSignInWithAppleFlow(with authRequest: ASAuthorizationAppleIDRequest? = nil) {
        let request: ASAuthorizationAppleIDRequest
        if let authRequest = authRequest {
            request = authRequest
        } else {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            request = appleIDProvider.createRequest()
        }
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = delegate
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    // Adapted from https://auth0.com/docs/api-auth/tutorials/nonce#generate-a-cryptographically-random-nonce
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    assert(false, "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
}

#if canImport(UIKit)
extension AppleAuthClient: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }),
              let delegate = scene.delegate as? UIWindowSceneDelegate,
              let window = delegate.window as? UIWindow else {
            assert(false)
            return UIWindow()
        }
        return window
    }
}

#elseif canImport(AppKit)
extension AppleAuthClient: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = NSApplication.shared.keyWindow else {
            assert(false)
            return NSWindow()
        }
        return window
    }
}
#endif

public extension AppleAuthClient {
    class Delegator: ASAuthorizationControllerDelegate {

        private let errorRelay: CurrentValueSubject<Error?, Never> = .init(nil)
        private let credentialRelay: CurrentValueSubject<OAuthCredential?, Never> = .init(nil)

        public var error: AnyPublisher<Error, Never> {
            errorRelay.compactMap({ $0 }).eraseToAnyPublisher()
        }

        public var credential: AnyPublisher<OAuthCredential, Never> {
            credentialRelay.compactMap({ $0 }).eraseToAnyPublisher()
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            errorRelay.send(error)
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            // MARK: STEP2: Handle Response and Create Credential for FirebaseAuth
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorRelay.send(AppleAuthClientError.failedToCastCredential)
                return
            }
            guard let nonce = currentNonce else {
                errorRelay.send(AppleAuthClientError.emptyNonce)
                return
            }
            guard let appleIdToken = credential.identityToken,
                  let idTokenString = String(data: appleIdToken, encoding: .utf8)
            else {
                errorRelay.send(AppleAuthClientError.emptyIdToken)
                return
            }

            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nonce
            )
            credentialRelay.send(credential)
        }
    }
}
