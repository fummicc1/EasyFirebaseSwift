//
//  MessageApp.swift
//  Shared
//
//  Created by Fumiya Tanaka on 2022/04/21.
//

import SwiftUI
import FirebaseCore

@main
struct MessageApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                RootView()
                    .environmentObject(RepositoryImpl())
            }
            .environmentObject(RepositoryImpl())
        }
    }
}
