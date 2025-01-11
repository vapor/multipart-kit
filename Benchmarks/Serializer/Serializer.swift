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
        for _ in benchmark.scaledIterations {
            let serializer = MultipartSerializer(boundary: "boundary123")
            let serialized = try serializer.serialize(parts: onePart)
            blackHole(serialized)
        }
    }

    Benchmark(
        "1000xSerializerCPUTime",
        configuration: .init(
            metrics: [.cpuUser],
            scalingFactor: .kilo
        )
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            let serializer = MultipartSerializer(boundary: "boundary123")
            let serialized = try serializer.serialize(parts: repeatedParts)
            blackHole(serialized)
        }
    }
}
