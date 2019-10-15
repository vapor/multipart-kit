// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "multipart",
    products: [
        .library(name: "Multipart", targets: ["Multipart"]),
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-nio.git", from: "2.2.0"),
    ],
    targets: [
        .target(name: "CMultipartParser"),
        .target(name: "Multipart", dependencies: [
          "CMultipartParser",
          "NIO",
          "NIOHTTP1",
          "NIOFoundationCompat"
        ]),
        .testTarget(name: "MultipartTests", dependencies: ["Multipart"]),
    ]
)
