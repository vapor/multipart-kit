// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Multipart",
    products: [
        .library(name: "Multipart", targets: ["Multipart"]),
    ],
    dependencies: [
        // 🌎 Utility package containing tools for byte manipulation, Codable, OS APIs, and debugging.
        .package(url: "https://github.com/vapor/core.git", from: "3.0.0"),
    ],
    targets: [
        .target(name: "Multipart", dependencies: ["Bits", "Core", "Debugging"]),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),
    ]
)
