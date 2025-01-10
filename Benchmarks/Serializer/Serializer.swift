import Benchmark
import MultipartKit

let example: MultipartPart = .init(
    headerFields: .init([
        .init(name: .contentDisposition, value: "form-data; name=\"file\"; filename=\"hello.txt\""),
        .init(name: .contentType, value: "text/plain"),
    ]),
    body: ArraySlice("Hello, world!".utf8)
)

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: [.peakMemoryResident, .mallocCountTotal],
        thresholds: [
            .peakMemoryResident: .init(
                /// Tolerate up to 2% of difference compared to the threshold.
                relative: [.p90: 2],
                /// Tolerate up to one million bytes of difference compared to the threshold.
                absolute: [.p90: 1_100_000]
            ),
            .mallocCountTotal: .init(
                /// Tolerate up to 1% of difference compared to the threshold.
                relative: [.p90: 1],
                /// Tolerate up to 2 malloc calls of difference compared to the threshold.
                absolute: [.p90: 2]
            ),
        ]
    )

    Benchmark(
        "Serializer Allocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        _ = try MultipartSerializer(boundary: "boundary123").serialize(parts: [example])
    }

    Benchmark(
        "Serializer Throughput",
        configuration: .init(
            metrics: [
                .throughput,
                .wallClock,
                .cpuTotal
            ]
        )
    ){ benchmark in
        let parts: [MultipartPart] = .init(repeating: example, count: 1000)

        benchmark.startMeasurement()
        _ = try MultipartSerializer(boundary: "boundary123").serialize(parts: parts)
        benchmark.stopMeasurement()
    }
}
