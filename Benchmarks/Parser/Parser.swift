import Benchmark
import MultipartKit

let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    let bigMessage = makeMessage(boundary: boundary, size: 1 << 27)  // 128MiB: Big message
    nonisolated(unsafe) var bufferStream1 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    nonisolated(unsafe) var bufferStream2 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    nonisolated(unsafe) var bufferStream3 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    nonisolated(unsafe) var bufferStream4 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    nonisolated(unsafe) var bufferStream5 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    nonisolated(unsafe) var bufferStream6 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    nonisolated(unsafe) var bufferStream7 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    nonisolated(unsafe) var bufferStream8 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    nonisolated(unsafe) var bufferStream9 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
    nonisolated(unsafe) var bufferStream10 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)

    Benchmark(
        "StreamingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1,
            teardown: {
                bufferStream1 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
            }
        )
    ) { benchmark in
        let streamingSequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream1)
        for try await part in streamingSequence {
            blackHole(part)
        }
    }

    Benchmark(
        "10xStreamingParserCPUTime",
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
            teardown: {
                bufferStream1 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream2 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream3 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream4 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream5 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream6 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream7 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream8 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream9 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream10 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
            }
        )
    ) { benchmark in
        let sequence1 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream1)
        for try await part in sequence1 { blackHole(part) }

        let sequence2 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream2)
        for try await part in sequence2 { blackHole(part) }

        let sequence3 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream3)
        for try await part in sequence3 { blackHole(part) }

        let sequence4 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream4)
        for try await part in sequence4 { blackHole(part) }

        let sequence5 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream5)
        for try await part in sequence5 { blackHole(part) }

        let sequence6 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream6)
        for try await part in sequence6 { blackHole(part) }

        let sequence7 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream7)
        for try await part in sequence7 { blackHole(part) }

        let sequence8 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream8)
        for try await part in sequence8 { blackHole(part) }

        let sequence9 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream9)
        for try await part in sequence9 { blackHole(part) }

        let sequence10 = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream10)
        for try await part in sequence10 { blackHole(part) }
    }

    Benchmark(
        "CollatingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1,
            teardown: {
                bufferStream1 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
            }
        )
    ) { benchmark in
        let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream1)
        for try await part in sequence { blackHole(part) }
    }

    Benchmark(
        "10xCollatingParserCPUTime",
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
            teardown: {
                bufferStream1 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream2 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream3 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream4 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream5 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream6 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream7 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream8 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream9 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
                bufferStream10 = makeParsingStream(for: bigMessage, chunkSize: 1 << 14)
            }
        )
    ) { benchmark in
        let sequence1 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream1)
        for try await part in sequence1 { blackHole(part) }

        let sequence2 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream2)
        for try await part in sequence2 { blackHole(part) }

        let sequence3 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream3)
        for try await part in sequence3 { blackHole(part) }

        let sequence4 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream4)
        for try await part in sequence4 { blackHole(part) }

        let sequence5 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream5)
        for try await part in sequence5 { blackHole(part) }

        let sequence6 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream6)
        for try await part in sequence6 { blackHole(part) }

        let sequence7 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream7)
        for try await part in sequence7 { blackHole(part) }

        let sequence8 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream8)
        for try await part in sequence8 { blackHole(part) }

        let sequence9 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream9)
        for try await part in sequence9 { blackHole(part) }

        let sequence10 = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream10)
        for try await part in sequence10 { blackHole(part) }
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
