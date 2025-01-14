import Algorithms
import Benchmark
import MultipartKit

let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    let approxSizeInMiB = 256
    let chunkSizeInKiB = 16
    let chunkedMessage = makeChunks(
        for: makeMessage(
            boundary: boundary,
            size: approxSizeInMiB << 20
        ),
        chunkSize: chunkSizeInKiB << 10
    )

    let cpuBenchsWarmupIterations = 5
    let cpuBenchsMaxIterations = 20
    let maxBufferStreamsUsedInBenchs = cpuBenchsWarmupIterations + cpuBenchsMaxIterations

    var bufferStreams: [AsyncSyncSequence<[ArraySlice<UInt8>]>] = []
    var benchmarkIterated = 0

    func refreshBufferStreams() {
        bufferStreams = (0..<maxBufferStreamsUsedInBenchs).map { _ in
            chunkedMessage.async
        }
    }

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

    benchmarkIterated = 0
    refreshBufferStreams()
    Benchmark(
        "StreamingParserAllocations_\(approxSizeInMiB)MiB",
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
        defer { benchmarkIterated += 1 }

        let sequence = StreamingMultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStreams[benchmarkIterated]
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    benchmarkIterated = 0
    refreshBufferStreams()
    Benchmark(
        "StreamingParserCPUTime_\(approxSizeInMiB)MiB",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: cpuBenchsWarmupIterations,
            maxDuration: .seconds(20),
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
        defer { benchmarkIterated += 1 }

        let sequence = StreamingMultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStreams[benchmarkIterated]
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

    benchmarkIterated = 0
    refreshBufferStreams()
    Benchmark(
        "CollatingParserAllocations_\(approxSizeInMiB)MiB",
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
        defer { benchmarkIterated += 1 }

        let sequence = MultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStreams[benchmarkIterated]
        )
        for try await part in sequence {
            blackHole(part)
        }
    }

    benchmarkIterated = 0
    refreshBufferStreams()
    Benchmark(
        "CollatingParserCPUTime_\(approxSizeInMiB)MiB",
        configuration: .init(
            metrics: [.cpuUser],
            warmupIterations: cpuBenchsWarmupIterations,
            maxDuration: .seconds(20),
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
        defer { benchmarkIterated += 1 }

        let sequence = MultipartParserAsyncSequence(
            boundary: boundary,
            buffer: bufferStreams[benchmarkIterated]
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
