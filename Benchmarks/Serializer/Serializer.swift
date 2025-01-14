import Benchmark
import MultipartKit

let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    let examplePart: MultipartPart = .init(
        headerFields: .init([
            .init(name: .contentDisposition, value: "form-data; name=\"file\"; filename=\"hello.txt\""),
            .init(name: .contentType, value: "text/plain"),
        ]),
        body: ArraySlice("Hello, world!".utf8)
    )
    let emptyParts: [MultipartPart<ArraySlice<UInt8>>] = []
    let partCount = 1 << 10
    let repeatedParts: [MultipartPart] = .init(repeating: examplePart, count: partCount)

    Benchmark(
        "SerializerAllocations_Empty",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let serializer = MultipartSerializer(boundary: boundary)
        let serialized = try serializer.serialize(parts: emptyParts)
        blackHole(serialized)
    }

    Benchmark(
        "SerializerAllocations_\(partCount)Parts",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let serializer = MultipartSerializer(boundary: boundary)
        let serialized = try serializer.serialize(parts: repeatedParts)
        blackHole(serialized)
    }

    Benchmark(
        "100xSerializerCPUTime_\(partCount)Parts",
        configuration: .init(
            metrics: [.cpuUser],
            maxDuration: .seconds(10),
            maxIterations: 20,
            thresholds: [
                .cpuUser: .init(
                    /// `6 - 1 == 5`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 6],
                    /// 11ms of tolerance.
                    absolute: [.p90: 11_000_000]
                )
            ]
        )
    ) { benchmark in
        for _ in 0..<100 {
            let serializer = MultipartSerializer(boundary: boundary)
            let serialized = try serializer.serialize(parts: repeatedParts)
            blackHole(serialized)
        }
    }
}
