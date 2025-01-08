// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "multipart-kit",
    platforms: [
        .macOS(.v10_15),
        .macCatalyst(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
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
            ],
            exclude: ["Docs.docc"]
        ),
        .testTarget(
            name: "MultipartKitTests",
            dependencies: [
                .target(name: "MultipartKit")
            ]
        ),
    ]
)
