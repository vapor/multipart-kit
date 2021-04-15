// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "multipart-kit",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(name: "MultipartKit", targets: ["MultipartKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.2.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "0.0.2")
    ],
    targets: [
        .target(name: "MultipartKit", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
            .product(name: "OrderedCollections", package: "swift-collections")
        ]),
        .testTarget(name: "MultipartKitTests", dependencies: ["MultipartKit"]),
    ]
)
