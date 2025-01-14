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
            ],
            path: "Parser",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
    ]
)
