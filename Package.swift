// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "EasyFirebaseSwift",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "EasyFirebaseSwift",
            targets: ["EasyFirebaseSwift"]
        )
    ],
    dependencies: [
        .package(name: "Firebase", url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMinor(from: "7.11.0"))
    ],
    targets: [
        .target(
            name: "EasyFirebaseSwift",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "Firebase"),
                .product(name: "FirebaseFirestoreSwift-Beta", package: "Firebase"),
                    .product(name: "FirebaseAuth", package: "Firebase")
            ]
        )
    ]
)
