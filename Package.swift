// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "EasyFirebase",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "EasyFirebaseAuth",
            targets: ["EasyFirebaseAuth"]
        ),
        .library(
            name: "EasyFirebaseFirestore",
            targets: ["EasyFirebaseFirestore"]
        ),
        .library(
            name: "EasyFirebaseStorage",
            targets: ["EasyFirebaseStorage"]
        )
    ],
    dependencies: [
        .package(
            name: "Firebase",
            url: "https://github.com/firebase/firebase-ios-sdk",
            .upToNextMajor(from: "10.24.0")
        )
    ],
    targets: [
        .target(
            name: "EasyFirebaseAuth",
            dependencies: [
                .product(name: "FirebaseAuth", package: "Firebase")
            ],
            path: "Sources/Auth"
        ),
        .target(
            name: "EasyFirebaseFirestore",
            dependencies: [
                .product(
                    name: "FirebaseFirestore",
                    package: "Firebase"
                ),
                .product(
                    name: "FirebaseFirestoreSwift",
                    package: "Firebase"
                )
            ],
            path: "Sources/Firestore"
        ),
        .target(
            name: "EasyFirebaseStorage",
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
                .target(name: "EasyFirebaseFirestore"),
                .target(name: "TestCore")
            ]
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: [
                .target(name: "EasyFirebaseStorage"),
                .target(name: "TestCore")
            ]
        )
    ]
)
