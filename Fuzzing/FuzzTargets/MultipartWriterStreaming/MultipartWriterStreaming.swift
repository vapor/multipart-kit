import Fuzzing
import HTTPTypes
import MultipartKit

private func stream(_ sections: [MultipartSection<[UInt8]>]) -> AsyncStream<MultipartSection<[UInt8]>> {
    AsyncStream { continuation in
        for section in sections { continuation.yield(section) }
        continuation.finish()
    }
}

let fuzzTargets: @Sendable () -> Void = {
    // The streaming writer — a different implementation of `MultipartWriter`
    // from the in-memory one `MultipartRoundTrip` uses, and 662 edges that no
    // other target reaches.
    //
    // Same oracle as the in-memory round trip: what this library serialises must
    // parse back. Serialising through a different writer and parsing with the
    // same parser is also the shape that catches two implementations of one
    // format disagreeing with each other.
    FuzzTarget.structuredAsync("MultipartWriterStreaming") { data in
        var data = data
        let boundary = "boundary123"
        let boundaryBytes = Array("--\(boundary)".utf8)

        var sections: [MultipartSection<[UInt8]>] = []
        var bodies: [[UInt8]] = []
        var smuggled = false

        let partCount = Int(data.integer(in: UInt8(1)...UInt8(6)))
        for _ in 0..<partCount {
            // The section stream carries its own delimiters: the writer emits
            // what it is given, so a stream without boundary sections produces a
            // message with no boundaries in it. Omitting these was a harness
            // bug that looked exactly like a writer/parser disagreement.
            sections.append(.boundary(end: false))

            var fields = HTTPFields()
            let name = data.element(of: ["a", "file", "", "0"]) ?? "a"
            fields[.contentDisposition] = "form-data; name=\"\(name)\""
            sections.append(.headerFields(fields))

            let body = data.chunk()
            // Multipart has no escaping, so a body carrying the delimiter
            // splits differently on the way back for reasons belonging to the
            // format. Serialise it anyway — that is coverage — and only skip
            // the equality check.
            if body.containsSubsequence(boundaryBytes) { smuggled = true }
            sections.append(.bodyChunk(body))
            bodies.append(body)
        }

        sections.append(.boundary(end: true))

        let sequence = StreamingMultipartWriterAsyncSequence(
            backingSequence: stream(sections),
            boundary: boundary,
            outboundBody: [UInt8].self
        )

        var serialized: [UInt8] = []
        do {
            for try await chunk in sequence { serialized.append(contentsOf: chunk) }
        } catch {
            return
        }

        let parsed = try? MultipartParser<[UInt8]>(boundary: boundary).parse(serialized)
        guard !smuggled else { return }

        guard let parsed else {
            fatalError("the streaming writer produced a message this library cannot parse")
        }
        guard parsed.count == bodies.count else {
            fatalError("wrote \(bodies.count) parts, parsed back \(parsed.count)")
        }
        for (original, returned) in zip(bodies, parsed) where original != returned.body {
            fatalError("a part body did not survive the streaming round trip")
        }
    }
}

extension Collection where Element: Equatable {
    fileprivate func containsSubsequence(_ needle: [Element]) -> Bool {
        guard !needle.isEmpty, count >= needle.count else { return false }
        var start = startIndex
        for _ in 0...(count - needle.count) {
            if self[start...].starts(with: needle) { return true }
            start = index(after: start)
        }
        return false
    }
}
