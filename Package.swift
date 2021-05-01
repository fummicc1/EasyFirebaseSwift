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
        .package(name: "Firebase", url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMinor(from: "7.11.0"))
    ],
    targets: [
        .target(
            name: "EasyFirebaseFirestoreSwift",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "Firebase"),
                .product(name: "FirebaseFirestoreSwift-Beta", package: "Firebase")
            ]
        )
    ]
)
