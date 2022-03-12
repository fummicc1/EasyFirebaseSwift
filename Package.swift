// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "EasyFirebaseSwift",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "EasyFirebaseSwift-Auth",
            targets: ["EasyFirebaseSwift-Auth"]
        ),
        .library(
            name: "EasyFirebaseSwift-Firestore",
            targets: ["EasyFirebaseSwift-Firestore"]
        ),
        .library(
            name: "EasyFirebaseSwift-Storage",
            targets: ["EasyFirebaseSwift-Storage"]
        )
    ],
    dependencies: [
        .package(
            name: "Firebase",
            url: "https://github.com/firebase/firebase-ios-sdk",
            .upToNextMajor(from: "8.10.0")
        )
    ],
    targets: [
        .target(
            name: "EasyFirebaseSwift-Auth",
            dependencies: [
                .product(name: "FirebaseAuth", package: "Firebase")
            ]
        ),
        .target(
            name: "EasyFirebaseSwift-Firestore",
            dependencies: [
                .product(
                    name: "FirebaseFirestore",
                    package: "Firebase"
                ),
                .product(
                    name: "FirebaseFirestoreSwift-Beta",
                    package: "Firebase"
                )
            ]
        ),
        .target(
            name: "EasyFirebaseSwift-Storage",
            dependencies: [
                .product(name: "FirebaseStorage", package: "Firebase")
            ]
        ),
        .testTarget(
            name: "EasyFirebaseSwiftTests",
            dependencies: [
                .target(name: "EasyFirebaseSwift-Auth"),
                .target(name: "EasyFirebaseSwift-Firestore"),
                .target(name: "EasyFirebaseSwift-Storage")
            ]
        )
    ]
)
