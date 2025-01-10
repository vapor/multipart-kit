import Benchmark
import MultipartKit

// Note: the throughput benchmarks use streams which yield with a delay
// to simulate async work.
let benchmarks: @Sendable () -> Void = {
    Benchmark(
        "StreamingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        let boundary = "boundary123"
        let bigMessage = makeMessage(boundary: boundary, size: 500_000_000) // 500MB: Big message
        let bigMessageStream = makeParsingStream(for: bigMessage, chunkSize: 16 * 1024) // 16KB: Realistic streaming chunk size

        let sequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bigMessageStream)

        benchmark.startMeasurement()
        for try await _ in sequence {}
        benchmark.stopMeasurement()
    }

    Benchmark(
        "StreamingParserThroughput",
        configuration: .init(
            metrics: [
                .cpuTotal,
                .wallClock,
                .throughput
            ]
        )
    ) { benchmark in
        let boundary = "boundary123"
        let bigMessage = makeMessage(boundary: boundary, size: 500_000_000)
        let bigMessageStream = makeParsingStream(for: bigMessage, chunkSize: 16 * 1024, delay: true)

        let sequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: bigMessageStream)

        benchmark.startMeasurement()
        for try await _ in sequence {}
        benchmark.stopMeasurement()
    }

    Benchmark(
        "CollatingParserAllocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        let boundary = "boundary123"
        let bigMessage = makeMessage(boundary: boundary, size: 500_000_000)
        let bigMessageStream = makeParsingStream(for: bigMessage, chunkSize: 16 * 1024)

        let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: bigMessageStream)

        benchmark.startMeasurement()
        defer { benchmark.stopMeasurement() }
        for try await _ in sequence {}
    }

    Benchmark(
        "CollatingParserThroughput",
        configuration: .init(
            metrics: [
                .cpuTotal,
                .wallClock,
                .throughput
            ]
        )
    ) { benchmark in
        let boundary = "boundary123"
        let bigMessage = makeMessage(boundary: boundary, size: 500_000_000)
        let bigMessageStream = makeParsingStream(for: bigMessage, chunkSize: 16 * 1024, delay: true)

        let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: bigMessageStream)

        benchmark.startMeasurement()
        for try await _ in sequence {}
        benchmark.stopMeasurement()
    }
}

private func makeParsingStream<Body: MultipartPartBodyElement>(for message: Body, chunkSize: Int, delay: Bool = false) -> AsyncStream<Body.SubSequence>
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

    message.append(contentsOf: Array(repeating: UInt8.random(in: 0...255), count: size))
    message.append(contentsOf: "\r\n--\(boundary)--".utf8)

    return message
}
