// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "multipart-kit",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(name: "MultipartKit", targets: ["MultipartKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "MultipartKit",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "MultipartKitTests",
            dependencies: [
                .target(name: "MultipartKit")
            ]
        ),
    ]
)
