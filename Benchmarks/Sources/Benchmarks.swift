import Benchmark
import MultipartKit

let benchmarks: @Sendable () -> Void = {
    Benchmark(
        "Parser Allocations",
        configuration: .init(
            metrics: [.mallocCountTotal]
        )
    ) { benchmark in
        let boundary = "boundary123"
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

        message.append(contentsOf: Array(repeating: UInt8.random(in: 0...255), count: 500_000_000)) // 500MB
        message.append(contentsOf: "\r\n--\(boundary)--".utf8)

        let stream = AsyncStream { continuation in
            var offset = message.startIndex
            while offset < message.endIndex {
                let endIndex = min(message.endIndex, message.index(offset, offsetBy: 16))
                continuation.yield(message[offset..<endIndex])
                offset = endIndex
            }
            continuation.finish()
        }
        
        let sequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: stream)

        benchmark.startMeasurement()
        defer { benchmark.stopMeasurement() }
        for try await _ in sequence {}
    }
}
