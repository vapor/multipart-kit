import Fuzzing
import HTTPTypes
@_spi(StreamingMultipartPart) import MultipartKit

/// Yields a fixed array of sections, the way the tests do.
private func stream(_ sections: [MultipartSection<[UInt8]>]) -> AsyncStream<MultipartSection<[UInt8]>> {
    AsyncStream { continuation in
        for section in sections { continuation.yield(section) }
        continuation.finish()
    }
}

/// `MultipartSection` is not `Equatable`, so compare a normalised token instead.
private enum Token: Equatable {
    case headers(HTTPFields)
    case body([UInt8])
    case boundary(end: Bool)
}

private func tokens(_ sections: [MultipartSection<[UInt8]>]) -> [Token] {
    sections.map { section in
        switch section {
        case .headerFields(let fields): .headers(fields)
        case .bodyChunk(let bytes): .body(Array(bytes))
        case .boundary(let end): .boundary(end: end)
        }
    }
}

let fuzzTargets: @Sendable () -> Void = {
    // The per-part streaming API, which is the largest thing in this package no
    // other target enters: `StreamingMultipartPart+SharedIterator` alone is 1180
    // edges, and it and `StreamingMultipartSectionAsyncSequence` were both at
    // zero after 2.66 million executions across the first four targets.
    //
    // It is `@_spi(StreamingMultipartPart)`, not fully public — Vapor is the
    // consumer it exists for. The tests import it the same way.
    //
    // Sections are built well-formed rather than fuzzed freely, because that is
    // the realistic input: these sequences consume what the parser produced, and
    // the parser does not emit a body chunk before a boundary. The oracle is
    // therefore a genuine fixed point — sections grouped into parts and flattened
    // back must be the sections you started with.
    FuzzTarget.structuredAsync("MultipartSections") { data in
        var data = data

        var sections: [MultipartSection<[UInt8]>] = []
        let partCount = Int(data.integer(in: UInt8(1)...UInt8(6)))
        for _ in 0..<partCount {
            sections.append(.boundary(end: false))

            var fields = HTTPFields()
            let name = data.element(of: ["a", "file", "", "x-y"]) ?? "a"
            fields[.contentDisposition] = "form-data; name=\"\(name)\""
            if let type = data.element(of: ["text/plain", "application/octet-stream", ""]) {
                fields[.contentType] = type
            }
            sections.append(.headerFields(fields))

            // Several chunks per part, so the grouping logic sees a body split
            // across reads rather than arriving whole.
            let chunkCount = Int(data.integer(in: UInt8(0)...UInt8(4)))
            for _ in 0..<chunkCount {
                sections.append(.bodyChunk(data.chunk()))
            }
        }
        sections.append(.boundary(end: true))

        let parts = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let flattened = StreamingMultipartSectionAsyncSequence(parts: parts)

        var output: [MultipartSection<[UInt8]>] = []
        do {
            for try await section in flattened { output.append(section) }
        } catch {
            fatalError("well-formed sections failed to round-trip through the part grouper")
        }

        guard tokens(output) == tokens(sections) else {
            fatalError("sections -> parts -> sections is not a fixed point")
        }
    }
}
