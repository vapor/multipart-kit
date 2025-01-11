import Benchmark
import MultipartKit

// Note: the `cpuUser` benchmarks use streams which yield with a delay
// to simulate async work.
let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    let bigMessage = makeMessage(boundary: boundary, size: 1 << 24) // 400MiB: Big message
    let bigMessageStream = makeParsingStream(for: bigMessage, chunkSize: 1 << 14) // 16KiB: Realistic streaming chunk size

    let streamingSequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bigMessageStream)
    let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: bigMessageStream)

    Benchmark(
        "StreamingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        for _ in benchmark.iterations {
            for try await element in streamingSequence {
                blackHole(element)
            }
        }
    }

    Benchmark(
        "StreamingParserCPUTime",
        configuration: .init(
            metrics: [.cpuUser]
        )
    ) { benchmark in
        for _ in benchmark.iterations {
            for try await element in streamingSequence {
                blackHole(element)
            }
        }
    }

    Benchmark(
        "CollatingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        for _ in benchmark.iterations {
            for try await element in sequence {
                blackHole(element)
            }
        }
    }

    Benchmark(
        "CollatingParserCPUTime",
        configuration: .init(
            metrics: [.cpuUser]
        )
    ) { benchmark in
        for _ in benchmark.iterations {
            for try await element in sequence {
                blackHole(element)
            }
        }
    }
}

private func makeParsingStream<Body: MultipartPartBodyElement>(for message: Body, chunkSize: Int, delay: Bool = false) -> AsyncStream<
    Body.SubSequence
>
where Body.SubSequence: Sendable {
    AsyncStream<Body.SubSequence> { continuation in
        var offset = message.startIndex
        while offset < message.endIndex {
            let endIndex = min(message.endIndex, message.index(offset, offsetBy: chunkSize))

            if delay {
                // Simulate async work
                Task.detached {
                    try? await Task.sleep(for: .milliseconds(1))
                }
            }

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
