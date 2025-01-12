import Benchmark
import MultipartKit

let benchmarks: @Sendable () -> Void = {
    let examplePart: MultipartPart = .init(
        headerFields: .init([
            .init(name: .contentDisposition, value: "form-data; name=\"file\"; filename=\"hello.txt\""),
            .init(name: .contentType, value: "text/plain"),
        ]),
        body: ArraySlice("Hello, world!".utf8)
    )
    let onePart: [MultipartPart] = [examplePart]
    let repeatedParts: [MultipartPart] = .init(repeating: examplePart, count: 1 << 10)

    Benchmark(
        "SerializerAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        let serializer = MultipartSerializer(boundary: "boundary123")
        let serialized = try serializer.serialize(parts: onePart)
        blackHole(serialized)
    }

    Benchmark(
        "10xSerializerCPUTime",
        configuration: .init(
            metrics: [.cpuUser],
            maxIterations: 10,
            thresholds: [
                .cpuUser: .init(
                    /// `5 - 1 == 4`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 5],
                    /// 11ms of tolerance.
                    absolute: [.p90: 11_000_000]
                )
            ]
        )
    ) { benchmark in
        for _ in 0..<10 {
            let serializer = MultipartSerializer(boundary: "boundary123")
            let serialized = try serializer.serialize(parts: repeatedParts)
            blackHole(serialized)
        }
    }
}
