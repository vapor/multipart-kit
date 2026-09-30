import Fuzzing
import HTTPTypes
import MultipartKit

/// Collects everything written, by reference, so the bytes survive the writer
/// being consumed. `BufferedMultipartWriter` keeps its wrapped writer
/// `internal`, so a value-type sink would be unreachable once handed over.
///
/// `@unchecked Sendable` is sound here in the way it usually is not: one fuzz
/// execution is single-threaded, and the sink never outlives it.
private final class Sink: @unchecked Sendable {
    var bytes: [UInt8] = []
}

private struct CapturingWriter: MultipartWriter {
    typealias OutboundBody = [UInt8]
    typealias Failure = Never

    let boundary: String
    let sink: Sink

    mutating func write(bytes: some Collection<UInt8> & Sendable) {
        sink.bytes.append(contentsOf: bytes)
    }

    mutating func finish() async {}
}

let fuzzTargets: @Sendable () -> Void = {
    // `BufferedMultipartWriter` wraps another writer and flushes through a fixed
    // capacity. The capacity is the whole point of this target: a buffering
    // layer's bugs live at the flush boundary — a part header that spans two
    // flushes, a body exactly the buffer's size, a capacity of one — and none of
    // them are reachable without varying it.
    FuzzTarget.structuredAsync("MultipartBufferedWriter") { data in
        var data = data
        let boundary = "boundary123"
        let boundaryBytes = Array("--\(boundary)".utf8)

        // Deliberately includes 1 and 2. A buffer that can hold almost nothing
        // flushes on nearly every write, which is the case a fixed 4KB default
        // never exercises.
        let capacity = Int(data.integer(in: UInt16(1)...UInt16(4096)))

        var parts: [MultipartPart<[UInt8]>] = []
        var smuggled = false
        let partCount = Int(data.integer(in: UInt8(1)...UInt8(6)))
        for _ in 0..<partCount {
            var fields = HTTPFields()
            let name = data.element(of: ["a", "file", "", "0"]) ?? "a"
            fields[.contentDisposition] = "form-data; name=\"\(name)\""
            if let type = data.element(of: ["text/plain", "application/octet-stream", ""]) {
                fields[.contentType] = type
            }
            let body = data.chunk()
            if body.containsSubsequence(boundaryBytes) { smuggled = true }
            parts.append(MultipartPart(headerFields: fields, body: body))
        }

        let sink = Sink()
        var writer = BufferedMultipartWriter(
            boundary: boundary,
            bufferCapacity: capacity,
            underlyingWriter: CapturingWriter(boundary: boundary, sink: sink)
        )
        for part in parts { await writer.writePart(part) }
        await writer.finish()
        let serialized = sink.bytes

        let parsed = try? MultipartParser<[UInt8]>(boundary: boundary).parse(serialized)
        guard !smuggled else { return }

        guard let parsed else {
            fatalError("buffered writer at capacity \(capacity) produced an unparseable message")
        }
        // The buffering must not change the message. A capacity that alters what
        // comes out the other end is the bug this target exists to find.
        guard parsed.count == parts.count else {
            fatalError("capacity \(capacity): wrote \(parts.count) parts, parsed back \(parsed.count)")
        }
        for (original, returned) in zip(parts, parsed) where original.body != returned.body {
            fatalError("capacity \(capacity): a part body did not survive buffering")
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
