import Benchmark
import MultipartKit

let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    let bigMessage = makeMessage(boundary: boundary, size: 1 << 26)  // 64MiB: Big message
    var bufferStreams: [AsyncStream<ArraySlice<UInt8>>] = .init(unsafeUninitializedCapacity: 100) { _, _ in }

    Benchmark(
        "StreamingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1,
            setup: {
                bufferStreams[0] = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
            }
        )
    ) { benchmark in
        let sequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStreams[0])
        for try await part in sequence { blackHole(part) }
    }

    Benchmark(
        "100xStreamingParserCPUTime",
        configuration: .init(
            metrics: [.cpuUser],
            maxDuration: .seconds(20),
            maxIterations: 10,
            thresholds: [
                .cpuUser: .init(
                    /// `9 - 1 == 8`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 9],
                    /// 26ms of tolerance.
                    absolute: [.p90: 26_000_000]
                )
            ],
            setup: {
                bufferStreams = (0..<100).map { _ in makeParsingStream(for: bigMessage, chunkSize: 1 << 14) }
            }
        )
    ) { benchmark in
        for bufferStream in bufferStreams {
            let sequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream)
            for try await part in sequence { blackHole(part) }
        }
    }

    Benchmark(
        "CollatingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1,
            setup: {
                bufferStreams[0] = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
            }
        )
    ) { benchmark in
        let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStreams[0])
        for try await part in sequence { blackHole(part) }
    }

    Benchmark(
        "100xCollatingParserCPUTime",
        configuration: .init(
            metrics: [.cpuUser],
            maxDuration: .seconds(20),
            maxIterations: 10,
            thresholds: [
                .cpuUser: .init(
                    /// `10 - 1 == 9`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 9],
                    /// 26ms of tolerance.
                    absolute: [.p90: 26_000_000]
                )
            ],
            setup: {
                bufferStreams = (0..<100).map { _ in makeParsingStream(for: bigMessage, chunkSize: 1 << 14) }
            }
        )
    ) { benchmark in
        for bufferStream in bufferStreams {
            let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream)
            for try await part in sequence { blackHole(part) }
        }
    }
}

private func makeParsingStream(
    for message: ArraySlice<UInt8>,
    chunkSize: Int
) -> AsyncStream<ArraySlice<UInt8>> {
    AsyncStream { continuation in
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
