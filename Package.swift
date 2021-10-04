// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "multipart-kit",
    products: [
        .library(name: "MultipartKit", targets: ["MultipartKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.2.0")
    ],
    targets: [
        .target(name: "MultipartKit", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ]),
        .testTarget(name: "MultipartKitTests", dependencies: ["MultipartKit"]),
    ]
)
