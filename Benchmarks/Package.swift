// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/benchmark.git", from: "1.35.0"),
    ],
    targets: [
        .executableTarget(
            name: "Writer",
            dependencies: [
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "Benchmark", package: "benchmark"),
                .target(name: "Utilities"),
            ],
            path: "Writer",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        ),
        .executableTarget(
            name: "Parser",
            dependencies: [
                .product(name: "MultipartKit", package: "multipart-kit"),
                .product(name: "Benchmark", package: "benchmark"),
                .target(name: "Utilities"),
            ],
            path: "Parser",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        ),
        .target(
            name: "Utilities",
            path: "Utilities"
        ),
    ]
)
