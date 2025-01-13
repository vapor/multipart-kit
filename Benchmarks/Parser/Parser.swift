import Algorithms
import Benchmark
import MultipartKit

let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    // 256MiB: Big message, 16KiB: Chunk size
    let chunkedMessage = Array(makeMessage(boundary: boundary, size: 1 << 28).chunks(ofCount: 1 << 14))
    let cpuBenchsWarmupIterations = 1
    let cpuBenchsMaxIterations = 10
    let cpuBenchsTotalIterations = cpuBenchsWarmupIterations + cpuBenchsMaxIterations
    var bufferStreams = (0..<cpuBenchsTotalIterations).map { _ in chunkedMessage.async }

    bufferStreams[0] = chunkedMessage.async
    Benchmark(
        "StreamingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let sequence = StreamingMultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStreams[0]
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    var streamingParserIterated = 0
    bufferStreams = (0..<cpuBenchsTotalIterations).map { _ in chunkedMessage.async }
    Benchmark(
        "StreamingParserCPUTime",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: cpuBenchsWarmupIterations,
            maxDuration: .seconds(20),
            maxIterations: cpuBenchsMaxIterations,
            thresholds: [
                .cpuUser: .init(
                    /// `10 - 1 == 9`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 9],
                    /// 26ms of tolerance.
                    absolute: [.p90: 26_000_000]
                )
            ]
        )
    ) { benchmark in
        defer { streamingParserIterated += 1 }

        let sequence = StreamingMultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStreams[streamingParserIterated]
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    bufferStreams[0] = chunkedMessage.async
    Benchmark(
        "CollatingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let sequence = MultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStreams[0]
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    var collatingParserIterated = 0
    bufferStreams = (0..<cpuBenchsTotalIterations).map { _ in chunkedMessage.async }
    Benchmark(
        "CollatingParserCPUTime",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: cpuBenchsWarmupIterations,
            maxDuration: .seconds(20),
            maxIterations: cpuBenchsMaxIterations,
            thresholds: [
                .cpuUser: .init(
                    /// `10 - 1 == 9`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 9],
                    /// 26ms of tolerance.
                    absolute: [.p90: 26_000_000]
                )
            ]
        )
    ) { benchmark in
        defer { collatingParserIterated += 1 }

        let sequence = MultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStreams[collatingParserIterated]
        )
        for try await part in sequence {
            blackHole(part)
        }
    }
}

private func makeMessage(boundary: String, size: Int) -> ArraySlice<UInt8> {
    var message = ArraySlice(
        """
        --\(boundary)\r
        Content-Disposition: form-data; name="id"\r
        Content-Type: text/plain\r
        \r
        123e4567-e89b-12d3-a456-426655440000\r
        --\(boundary)\r
        Content-Disposition: form-data; name="address"\r
        Content-Type: application/json\r
        \r
        {\r
        "street": "3, Garden St",\r
        "city": "Hillsbery, UT"\r
        }\r
        --\(boundary)\r
        Content-Disposition: form-data; name="profileImage"; filename="image1.png"\r
        Content-Type: image/png\r
        \r\n
        """.utf8)

    message.append(contentsOf: Array(repeating: UInt8.random(in: .min ... .max), count: size))
    message.append(contentsOf: "\r\n--\(boundary)--".utf8)

    return message
}
