// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "EasyFirebaseFirestoreSwift",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "EasyFirebaseFirestoreSwift",
            targets: ["EasyFirebaseFirestoreSwift"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMinor(from: "7.11.0"))
    ],
    targets: [
        .target(
            name: "EasyFirebaseFirestoreSwift",
            dependencies: [
                "FirebaseFirestore",
                "FirebaseFirestoreSwift-Beta"
            ],
            path: "EasyFirebaseFirestoreSwift"
        )
    ]
)
