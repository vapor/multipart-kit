// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "multipart",
    products: [
        .library(name: "Multipart", targets: ["Multipart"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Multipart"),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),
    ]
)
