// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "CodableKit",
    products: [
        .library(name: "CodableKit", targets: ["CodableKit"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "CodableKit", dependencies: []),
        .testTarget(name: "CodableKitTests", dependencies: ["CodableKit"]),
    ]
)
