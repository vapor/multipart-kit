// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.27.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.3"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "Serializer",
            dependencies: [
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "Benchmark", package: "package-benchmark"),
            ],
            path: "Serializer",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .executableTarget(
            name: "Parser",
            dependencies: [
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            path: "Parser",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
    ]
)
