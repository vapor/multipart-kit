import Benchmark
import HTTPTypes
import MultipartKit

struct File: Codable, MultipartPartConvertible {
    let data: [UInt8]

    var headerFields: HTTPFields {
        [.contentDisposition: "form-data; name=\"file\"; filename=\"file.bin\""]
    }

    func withBody<R>(_ closure: (RawSpan) throws -> R) rethrows -> R {
        if #available(macOS 26.0, *) {
            try closure(data.span.bytes)
        } else {
            try data.withUnsafeBytes { try closure($0.bytes) }
        }
    }

    init(data: [UInt8]) {
        self.data = data
    }

    init(headerFields: HTTPFields, body: RawSpan) throws {
        self.data = body.withUnsafeBytes { [UInt8]($0) }
    }
}

struct Upload: Codable {
    let file: File
}

let benchmarks: @Sendable () -> Void = {
    let boundary = "boundary123"
    let fileSizeInMiB = 10
    let upload = Upload(file: File(data: .init(repeating: 0x41, count: fileSizeInMiB << 20)))
    let encoded = try! FormDataEncoder().encode(upload, boundary: boundary, to: [UInt8].self)

    Benchmark(
        "Encoder_\(fileSizeInMiB)MiB_Allocations",
        configuration: .init(
            metrics: [.mallocCountTotal, .peakMemoryResident],
            maxIterations: 1,
            thresholds: [
                /// 1MiB of tolerance, well below the size of the file.
                .peakMemoryResident: .init(absolute: [.p90: 1 << 20])
            ]
        )
    ) { benchmark in
        blackHole(try FormDataEncoder().encode(upload, boundary: boundary, to: [UInt8].self))
    }

    Benchmark(
        "Decoder_\(fileSizeInMiB)MiB_Allocations",
        configuration: .init(
            metrics: [.mallocCountTotal, .peakMemoryResident],
            maxIterations: 1,
            thresholds: [
                /// 1MiB of tolerance, well below the size of the file.
                .peakMemoryResident: .init(absolute: [.p90: 1 << 20])
            ]
        )
    ) { benchmark in
        blackHole(try FormDataDecoder().decode(Upload.self, from: encoded, boundary: boundary))
    }

    Benchmark(
        "Encoder_\(fileSizeInMiB)MiB_Instructions",
        configuration: .init(
            metrics: [.instructions],
            maxDuration: .seconds(10),
            maxIterations: 20,
            thresholds: [
                /// Instruction counts are near-deterministic, so a small relative
                /// tolerance is enough; no absolute fudge needed.
                .instructions: .init(relative: [.p90: 3])
            ]
        )
    ) { benchmark in
        blackHole(try FormDataEncoder().encode(upload, boundary: boundary, to: [UInt8].self))
    }

    Benchmark(
        "Decoder_\(fileSizeInMiB)MiB_Instructions",
        configuration: .init(
            metrics: [.instructions],
            maxDuration: .seconds(10),
            maxIterations: 20,
            thresholds: [
                /// Instruction counts are near-deterministic, so a small relative
                /// tolerance is enough; no absolute fudge needed.
                .instructions: .init(relative: [.p90: 3])
            ]
        )
    ) { benchmark in
        blackHole(try FormDataDecoder().decode(Upload.self, from: encoded, boundary: boundary))
    }
}
