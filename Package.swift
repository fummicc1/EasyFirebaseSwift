// swift-tools-versions:5.3

import PackageDescription

let package = Package(
    name: "EasyFirebaseFirestoreSwift",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "EasyFirebaseFirestoreSwift",
            "targets": ["EasyFirebaseFirestoreSwift"]
        )
    ],
    targets: [
        .target(
            name: "EasyFirebaseFirestoreSwift",
            dependencies: [
                .package(url: )
            ],
            path: "EasyFirebaseFirestoreSwift"
        )
    ]
)