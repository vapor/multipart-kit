// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Multipart",
    products: [
        .library(name: "Multipart", targets: ["Multipart"]),
        .library(name: "FormData", targets: ["FormData"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/core.git", .upToNextMajor(from: "2.1.2")),
        .package(url: "https://github.com/vapor/engine.git", .upToNextMajor(from: "2.2.0")),
    ],
    targets: [
        .target(name: "Multipart", dependencies: ["Core", "HTTP"]),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),
        .target(name: "FormData", dependencies: ["Multipart", "Core"]),
        .testTarget(name: "FormDataTests", dependencies: ["FormData"]),
    ]
)
