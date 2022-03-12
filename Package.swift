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
            name: "EasyFirebaseSwiftAuth",
            targets: ["EasyFirebaseSwiftAuth"]
        ),
        .library(
            name: "EasyFirebaseSwiftFirestore",
            targets: ["EasyFirebaseSwiftFirestore"]
        ),
        .library(
            name: "EasyFirebaseSwiftStorage",
            targets: ["EasyFirebaseSwiftStorage"]
        )
    ],
    dependencies: [
        .package(
            name: "Firebase",
            url: "https://github.com/firebase/firebase-ios-sdk",
            .upToNextMajor(from: "8.13.0")
        )
    ],
    targets: [
        .target(
            name: "EasyFirebaseSwiftAuth",
            dependencies: [
                .product(name: "FirebaseAuth", package: "Firebase")
            ],
            path: "Sources/Auth"
        ),
        .target(
            name: "EasyFirebaseSwiftFirestore",
            dependencies: [
                .product(
                    name: "FirebaseFirestore",
                    package: "Firebase"
                ),
                .product(
                    name: "FirebaseFirestoreSwift-Beta",
                    package: "Firebase"
                )
            ],
            path: "Sources/Firestore"
        ),
        .target(
            name: "EasyFirebaseSwiftStorage",
            dependencies: [
                .product(name: "FirebaseStorage", package: "Firebase")
            ],
            path: "Sources/Storage"
        ),
        .target(
            name: "TestCore",
            dependencies: [
                .product(
                    name: "FirebaseAuth",
                    package: "Firebase"
                ),
                .product(
                    name: "FirebaseFirestore",
                    package: "Firebase"
                ),
                .product(
                    name: "FirebaseStorage",
                    package: "Firebase"
                )
            ],
            path: "Sources/TestCore"
        ),
        .testTarget(
            name: "FirestoreTests",
            dependencies: [
                .target(name: "EasyFirebaseSwiftFirestore"),
                .target(name: "TestCore")
            ]
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: [
                .target(name: "EasyFirebaseSwiftStorage"),
                .target(name: "TestCore")
            ]
        )
    ]
)
