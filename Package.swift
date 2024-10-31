// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "EasyFirebase",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
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
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk",
            .upToNextMajor(from: "10.24.0")
        )
    ],
    targets: [
        .target(
            name: "EasyFirebaseAuth",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
            ],
            path: "Sources/Auth"
        ),
        .target(
            name: "EasyFirebaseFirestore",
            dependencies: [
                .product(
                    name: "FirebaseFirestore",
                    package: "firebase-ios-sdk"
                ),
                .product(
                    name: "FirebaseFirestoreSwift",
                    package: "firebase-ios-sdk"
                ),
            ],
            path: "Sources/Firestore"
        ),
        .target(
            name: "EasyFirebaseStorage",
            dependencies: [
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk")
            ],
            path: "Sources/Storage"
        ),
        .target(
            name: "TestCore",
            dependencies: [
                .product(
                    name: "FirebaseAuth",
                    package: "firebase-ios-sdk"
                ),
                .product(
                    name: "FirebaseFirestore",
                    package: "firebase-ios-sdk"
                ),
                .product(
                    name: "FirebaseStorage",
                    package: "firebase-ios-sdk"
                ),
            ],
            path: "Sources/TestCore"
        ),
        .testTarget(
            name: "EasyFirebaseFirestoreTests",
            dependencies: [
                .target(name: "EasyFirebaseFirestore"),
                .target(name: "TestCore"),
            ]
        ),
        .testTarget(
            name: "EasyFirebaseStorageTests",
            dependencies: [
                .target(name: "EasyFirebaseStorage"),
                .target(name: "TestCore"),
            ]
        ),
    ]
)
