//
//  SignInWithAppleViewController.swift
//  AuthExample
//
//  Created by Fumiya Tanaka on 2022/01/01.
//

import UIKit
import EasyFirebaseSwift
import AuthenticationServices

class SignInWithAppleViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!

    private lazy var authClient: FirebaseAuthClient = FirebaseAuthClient()
    private lazy var appleAuthClient: AppleAuthClient = {
        let client = AppleAuthClient()
        return client
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // MARK: STEP0: Setup AuthenticationButton
        let style = traitCollection.userInterfaceStyle
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: style == .dark ? .whiteOutline : .black
        )
        button.addAction(
            UIAction(handler: { _ in
                self.startSignInWithApple()
            }),
            for: .primaryActionTriggered
        )
    }

    // MARK: STEP1: Start SignIn With Apple Flow
    private func startSignInWithApple() {
        // Show Authentication Alert
        // NOTE: Assign `delegate` before proceed.
//        appleAuthClient.delegate = self
        // `with` parameter is optional
        appleAuthClient.startSignInWithAppleFlow(with: nil)
    }
}
