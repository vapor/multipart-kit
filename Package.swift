// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "multipart-kit",
    platforms: [
       .macOS(.v10_14)
    ],
    products: [
        .library(name: "MultipartKit", targets: ["MultipartKit"]),
    ],
    dependencies: [ ],
    targets: [
        .target(name: "CMultipartParser"),
        .target(name: "MultipartKit", dependencies: [
          "CMultipartParser"
        ]),
        .testTarget(name: "MultipartKitTests", dependencies: ["MultipartKit"]),
    ]
)
