import Algorithms
import AsyncAlgorithms
import Benchmark
import MultipartKit

let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    // 512MiB: Big message, 16KiB: Chunk size
    let chunkedMessage = makeMessage(boundary: boundary, size: 1 << 29).chunks(ofCount: 1 << 14)
    var bufferStreams = (0..<10).map { _ in chunkedMessage.async }

    Benchmark(
        "StreamingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1,
            setup: {
                bufferStreams[0] = chunkedMessage.async
            }
        )
    ) { benchmark in
        let sequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bufferStreams[0])
        for try await part in sequence { blackHole(part) }
    }

    Benchmark(
        "StreamingParserCPUTime",
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
                bufferStreams = (0..<10).map { _ in chunkedMessage.async }
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
                bufferStreams[0] = chunkedMessage.async
            }
        )
    ) { benchmark in
        let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStreams[0])
        for try await part in sequence { blackHole(part) }
    }

    Benchmark(
        "CollatingParserCPUTime",
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
                bufferStreams = (0..<10).map { _ in chunkedMessage.async }
            }
        )
    ) { benchmark in
        for bufferStream in bufferStreams {
            let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: bufferStream)
            for try await part in sequence { blackHole(part) }
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
