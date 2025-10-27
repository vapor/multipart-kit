import Benchmark
import MultipartKit
import Utilities

let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    let examplePart: MultipartPart = .init(
        headerFields: .init([
            .init(name: .contentDisposition, value: "form-data; name=\"file\"; filename=\"hello.txt\""),
            .init(name: .contentType, value: "text/plain"),
        ]),
        body: ArraySlice("Hello, world!".utf8)
    )
    let emptyParts: [MultipartPart<ArraySlice<UInt8>>] = []
    let partCount = 1 << 10
    let repeatedParts: [MultipartPart] = .init(repeating: examplePart, count: partCount)

    let chunkSize = 64 << 10
    let fileSizeInMiB = 10
    let chunkedMessage: [MultipartSection<ArraySlice<UInt8>>] =
        [
            .headerFields([
                .contentDisposition: "form-data; name=\"file\"; filename=\"hello.txt\"",
                .contentType: "text/plain",
            ])
        ]
        + [MultipartSection<ArraySlice<UInt8>>](
            repeating: MultipartSection<ArraySlice<UInt8>>.bodyChunk(
                ArraySlice(repeatedParts[0].body.prefix(chunkSize))
            ),
            count: (fileSizeInMiB << 20) / chunkSize
        )

    let emptySections = [MultipartSection<ArraySlice<UInt8>>]()

    Benchmark(
        "MemoryWriter_Empty_Allocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: boundary)
        for part in emptyParts {
            try await writer.writePart(part)
        }
        blackHole(writer.getResult())
    }

    Benchmark(
        "MemoryWriter_\(partCount)Parts_Allocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: boundary)
        for part in repeatedParts {
            try await writer.writePart(part)
        }
        blackHole(writer.getResult())
    }

    Benchmark(
        "MemoryWriter_100x\(partCount)Parts_CPUTime",
        configuration: .init(
            metrics: [.cpuUser],
            maxDuration: .seconds(10),
            maxIterations: 20,
            thresholds: [
                .cpuUser: .init(
                    /// `6 - 1 == 5`% tolerance.
                    /// Will rely on the absolute threshold as the tighter threshold.
                    relative: [.p90: 6],
                    /// 11ms of tolerance.
                    absolute: [.p90: 11_000_000]
                )
            ]
        )
    ) { benchmark in
        for _ in 0..<100 {
            var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: boundary)
            for part in repeatedParts {
                try await writer.writePart(part)
            }
            blackHole(writer.getResult())
        }
    }

    Benchmark(
        "StreamingWriter_Empty_Allocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let sequence = StreamingMultipartWriterAsyncSequence(
            backingSequence: emptySections.async,
            boundary: boundary,
            outboundBody: ArraySlice<UInt8>.self
        )

        for try await part in sequence {
            blackHole(part)
        }
    }

    Benchmark(
        "StreamingWriter_\(fileSizeInMiB)MiB_Allocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let backingSequence = chunkedMessage.async

        benchmark.startMeasurement()
        let sequence = StreamingMultipartWriterAsyncSequence(
            backingSequence: backingSequence,
            boundary: boundary,
            outboundBody: ArraySlice<UInt8>.self
        )

        for try await part in sequence {
            blackHole(part)
        }
    }

    Benchmark(
        "BufferedWriter_16KB_\(partCount)Parts_Allocations",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let memoryWriter = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: boundary)
        var writer = BufferedMultipartWriter(
            boundary: boundary,
            bufferCapacity: 16 << 10,
            underlyingWriter: memoryWriter
        )

        for part in repeatedParts {
            try await writer.writePart(part)
        }

        try await writer.finish()
    }

    Benchmark(
        "BufferedWriter_Allocations\(fileSizeInMiB)MiB",
        configuration: .init(
            metrics: [.mallocCountTotal],
            maxIterations: 1
        )
    ) { benchmark in
        let memoryWriter = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: boundary)
        var writer = BufferedMultipartWriter(
            boundary: boundary,
            bufferCapacity: 256 << 10,  // 256KB buffer
            underlyingWriter: memoryWriter
        )

        let largeData = ArraySlice(Array(repeating: UInt8(65), count: fileSizeInMiB << 20))
        let largePart = MultipartPart(
            headerFields: [
                .contentDisposition: "form-data; name=\"file\"; filename=\"large.bin\"",
                .contentType: "application/octet-stream",
            ],
            body: largeData
        )

        benchmark.startMeasurement()
        try await writer.writePart(largePart)
        try await writer.finish()
        benchmark.stopMeasurement()
    }
}
