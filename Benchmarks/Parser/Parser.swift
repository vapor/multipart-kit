import Benchmark
import MultipartKit

let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    let fileSizeInMiB = 256
    let chunkSizeInKiB = 16
    let chunkedMessage = makeChunks(
        for: makeMessage(
            boundary: boundary,
            fileSize: fileSizeInMiB << 20
        ),
        chunkSize: chunkSizeInKiB << 10
    )

    let cpuBenchsWarmupIterations = 5
    let cpuBenchsMaxIterations = 20
    let cpuBenchsMaxDuration: Duration = .seconds(cpuBenchsMaxIterations + cpuBenchsWarmupIterations)
    let maxBufferStreamsUsedInBenchs = cpuBenchsWarmupIterations + cpuBenchsMaxIterations

    Benchmark(
        "StreamingParserAllocations_Empty",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let sequence = StreamingMultipartParserAsyncSequence(
            boundary: boundary,
            buffer: NoOpAsyncSequence()
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    Benchmark(
        "StreamingParserAllocations_\(fileSizeInMiB)MiB",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1,
            thresholds: [
                .mallocCountTotal: .init(
                    /// `2 - 1 == 1`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 2],
                    /// 500 allocations of tolerance.
                    absolute: [.p90: 500]
                )
            ]
        )
    ) { benchmark in
        let bufferStream = chunkedMessage.async

        benchmark.startMeasurement()
        let sequence = StreamingMultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStream
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    Benchmark(
        "StreamingParserCPUTime_\(fileSizeInMiB)MiB",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: cpuBenchsWarmupIterations,
            maxDuration: cpuBenchsMaxDuration,
            maxIterations: cpuBenchsMaxIterations,
            thresholds: [
                .cpuUser: .init(
                    /// `5 - 1 == 4`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 5],
                    /// 21ms of tolerance.
                    absolute: [.p90: 21_000_000]
                )
            ]
        )
    ) { benchmark in
        let bufferStream = chunkedMessage.async

        benchmark.startMeasurement()
        let sequence = StreamingMultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStream
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    Benchmark(
        "CollatingParserAllocations_Empty",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let sequence = MultipartParserAsyncSequence(
            boundary: boundary,
            buffer: NoOpAsyncSequence()
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    Benchmark(
        "CollatingParserAllocations_\(fileSizeInMiB)MiB",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1,
            thresholds: [
                .mallocCountTotal: .init(
                    /// `2 - 1 == 1`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 2],
                    /// 500 allocations of tolerance.
                    absolute: [.p90: 500]
                )
            ]
        )
    ) { benchmark in
        let bufferStream = chunkedMessage.async

        benchmark.startMeasurement()
        let sequence = MultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStream
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    Benchmark(
        "CollatingParserCPUTime_\(fileSizeInMiB)MiB",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: cpuBenchsWarmupIterations,
            maxDuration: cpuBenchsMaxDuration,
            maxIterations: cpuBenchsMaxIterations,
            thresholds: [
                .cpuUser: .init(
                    /// `5 - 1 == 4`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 5],
                    /// 21ms of tolerance.
                    absolute: [.p90: 21_000_000]
                )
            ]
        )
    ) { benchmark in
        let bufferStream = chunkedMessage.async

        benchmark.startMeasurement()
        let sequence = MultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStream
        )
        for try await part in sequence {
            blackHole(part)
        }
    }
}

private func makeChunks(
    for message: ArraySlice<UInt8>,
    chunkSize: Int
) -> [ArraySlice<UInt8>] {
    var chunks: [ArraySlice<UInt8>] = []
    let approxChunksCount = (message.count / chunkSize) + 2
    chunks.reserveCapacity(approxChunksCount)

    var offset = message.startIndex
    let endIndex = message.endIndex
    while offset < endIndex {
        let chunkEndIndex = min(endIndex, message.index(offset, offsetBy: chunkSize))
        chunks.append(message[offset..<chunkEndIndex])
        offset = chunkEndIndex
    }

    return chunks
}

private func makeMessage(boundary: String, fileSize: Int) -> ArraySlice<UInt8> {
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

    message.append(contentsOf: (0..<fileSize).map { UInt8($0 & 255) })
    message.append(contentsOf: "\r\n--\(boundary)--".utf8)

    return message
}
