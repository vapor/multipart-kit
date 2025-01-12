import Benchmark
import MultipartKit

// Note: the `cpuUser` benchmarks use streams which yield with a delay
// to simulate async work.
let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    let bigMessage = makeMessage(boundary: boundary, size: 1 << 24)  // 400MiB: Big message
    var messageStreams = (0..<500).map {
        _ in makeParsingStream(for: bigMessage, chunkSize: 1 << 14)  // 16KiB: Realistic streaming chunk size
    }

    let streamingStream = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    Benchmark(
        "StreamingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        let streamingSequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: streamingStream)
        for try await part in streamingSequence {
            blackHole(part)
        }
    }

    Benchmark(
        "10xStreamingParserCPUTime",
        configuration: .init(
            metrics: [.cpuUser],
            maxIterations: 10,
            thresholds: [
                .cpuUser: .init(
                    /// `8 - 1 == 7`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 8],
                    /// 21ms of tolerance.
                    absolute: [.p90: 21_000_000]
                )
            ]
        )
    ) { benchmark in
        for _ in 0..<10 {
            let bigMessageStream = messageStreams.removeFirst()
            let streamingSequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bigMessageStream)
            for try await part in streamingSequence {
                blackHole(part)
            }
        }
    }

    let collatingStream = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    Benchmark(
        "CollatingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: collatingStream)
        for try await part in sequence {
            blackHole(part)
        }
    }

    Benchmark(
        "10xCollatingParserCPUTime",
        configuration: .init(
            metrics: [.cpuUser],
            maxIterations: 10,
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
        for _ in 0..<10 {
            let bigMessageStream = messageStreams.removeFirst()
            let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: bigMessageStream)
            for try await part in sequence {
                blackHole(part)
            }
        }
    }
}

private func makeParsingStream<Body: MultipartPartBodyElement>(for message: Body, chunkSize: Int) -> AsyncStream<
    Body.SubSequence
>
where Body.SubSequence: Sendable {
    AsyncStream<Body.SubSequence> { continuation in
        var offset = message.startIndex
        while offset < message.endIndex {
            let endIndex = min(message.endIndex, message.index(offset, offsetBy: chunkSize))
            continuation.yield(message[offset..<endIndex])
            offset = endIndex
        }
        continuation.finish()
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
