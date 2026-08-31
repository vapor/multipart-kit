// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Fuzzing",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .macCatalyst(.v26),
        .visionOS(.v26),
        .watchOS(.v26),
    ],
    dependencies: [
        .package(path: "../"),
        .package(path: "/Users/timc/Developer/BrokenHands/swift-fuzz"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "MultipartParse",
            dependencies: ["MultipartParseTarget"],
            path: "FuzzTargets/MultipartParseShim"
        ),
        .target(
            name: "MultipartParseTarget",
            dependencies: [
                .product(name: "Fuzzing", package: "swift-fuzz"),
                .product(name: "MultipartKit", package: "multipart-kit"),
            ],
            path: "FuzzTargets/MultipartParse",
            plugins: [.plugin(name: "FuzzTargetPlugin", package: "swift-fuzz")]
        ),

        .executableTarget(
            name: "MultipartStreaming",
            dependencies: ["MultipartStreamingTarget"],
            path: "FuzzTargets/MultipartStreamingShim"
        ),
        .target(
            name: "MultipartStreamingTarget",
            dependencies: [
                .product(name: "Fuzzing", package: "swift-fuzz"),
                .product(name: "MultipartKit", package: "multipart-kit"),
            ],
            path: "FuzzTargets/MultipartStreaming",
            plugins: [.plugin(name: "FuzzTargetPlugin", package: "swift-fuzz")]
        ),

        .executableTarget(
            name: "MultipartRoundTrip",
            dependencies: ["MultipartRoundTripTarget"],
            path: "FuzzTargets/MultipartRoundTripShim"
        ),
        .target(
            name: "MultipartRoundTripTarget",
            dependencies: [
                .product(name: "Fuzzing", package: "swift-fuzz"),
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "FuzzTargets/MultipartRoundTrip",
            plugins: [.plugin(name: "FuzzTargetPlugin", package: "swift-fuzz")]
        ),

        .executableTarget(
            name: "FormDataDecode",
            dependencies: ["FormDataDecodeTarget"],
            path: "FuzzTargets/FormDataDecodeShim"
        ),
        .target(
            name: "FormDataDecodeTarget",
            dependencies: [
                .product(name: "Fuzzing", package: "swift-fuzz"),
                .product(name: "MultipartKit", package: "multipart-kit"),
            ],
            path: "FuzzTargets/FormDataDecode",
            plugins: [.plugin(name: "FuzzTargetPlugin", package: "swift-fuzz")]
        ),

        .executableTarget(
            name: "MultipartSections",
            dependencies: ["MultipartSectionsTarget"],
            path: "FuzzTargets/MultipartSectionsShim"
        ),
        .target(
            name: "MultipartSectionsTarget",
            dependencies: [
                .product(name: "Fuzzing", package: "swift-fuzz"),
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "FuzzTargets/MultipartSections",
            plugins: [.plugin(name: "FuzzTargetPlugin", package: "swift-fuzz")]
        ),

        .executableTarget(
            name: "MultipartWriterStreaming",
            dependencies: ["MultipartWriterStreamingTarget"],
            path: "FuzzTargets/MultipartWriterStreamingShim"
        ),
        .target(
            name: "MultipartWriterStreamingTarget",
            dependencies: [
                .product(name: "Fuzzing", package: "swift-fuzz"),
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "FuzzTargets/MultipartWriterStreaming",
            plugins: [.plugin(name: "FuzzTargetPlugin", package: "swift-fuzz")]
        ),

        .executableTarget(
            name: "MultipartBufferedWriter",
            dependencies: ["MultipartBufferedWriterTarget"],
            path: "FuzzTargets/MultipartBufferedWriterShim"
        ),
        .target(
            name: "MultipartBufferedWriterTarget",
            dependencies: [
                .product(name: "Fuzzing", package: "swift-fuzz"),
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "FuzzTargets/MultipartBufferedWriter",
            plugins: [.plugin(name: "FuzzTargetPlugin", package: "swift-fuzz")]
        ),

        .executableTarget(
            name: "FormDataRoundTrip",
            dependencies: ["FormDataRoundTripTarget"],
            path: "FuzzTargets/FormDataRoundTripShim"
        ),
        .target(
            name: "FormDataRoundTripTarget",
            dependencies: [
                .product(name: "Fuzzing", package: "swift-fuzz"),
                .product(name: "MultipartKit", package: "multipart-kit"),
            ],
            path: "FuzzTargets/FormDataRoundTrip",
            plugins: [.plugin(name: "FuzzTargetPlugin", package: "swift-fuzz")]
        ),
    ]
)
