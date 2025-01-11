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
    Benchmark(
        "SerializerAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        _ = try MultipartSerializer(boundary: "boundary123").serialize(parts: [example])
    }

    Benchmark(
        "SerializerThroughput",
        configuration: .init(
            metrics: [.cpuUser]
        )
    ) { benchmark in
        let parts: [MultipartPart] = .init(repeating: example, count: 1000)

        benchmark.startMeasurement()
        _ = try MultipartSerializer(boundary: "boundary123").serialize(parts: parts)
        benchmark.stopMeasurement()
    }
}
