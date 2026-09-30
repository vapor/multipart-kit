import Fuzzing
import HTTPTypes
import MultipartKit

let fuzzTargets: @Sendable () -> Void = {
    // The encode side, which no other target here enters at all —
    // `MultipartWriter.swift` is the largest file in the package and sat at
    // 0/1368 until this target existed.
    //
    // The oracle is a fixed point rather than "did not crash": a message this
    // library serialized must parse back through this library, and the bodies
    // must survive the trip. That is a much stronger statement than
    // crash-freedom, and it is the kind of property that catches a writer and a
    // parser disagreeing about their own format.
    FuzzTarget.structuredAsync("MultipartRoundTrip") { data in
        var data = data

        // A single valid boundary, deliberately. Fuzzing the boundary here would
        // test the writer's behaviour on illegal boundaries, which is
        // `MultipartParse`'s job — while making the fixed point untrue, because
        // an empty or `--` boundary produces a message no parser can split
        // unambiguously.
        let boundary = "boundary123"
        let boundaryBytes = Array("--\(boundary)".utf8)

        var parts: [MultipartPart<[UInt8]>] = []
        while !data.isEmpty && parts.count < 8 {
            let body = data.chunk()
            var fields = HTTPFields()
            // The name is drawn, not fuzzed. An unescaped quote or CRLF inside a
            // header value builds a header this library never would, and the
            // asymmetry that follows would be the harness's fault.
            let name = data.element(of: ["a", "file", "x-y", "", "0"]) ?? "a"
            fields[.contentDisposition] = "form-data; name=\"\(name)\""

            // Extra headers, because otherwise every part this target writes has
            // exactly one header and the writer's header serialisation takes the
            // same path every time. Coverage moved four edges in 473,000 runs
            // before this: the input was varying the bodies and nothing else,
            // and the writer does not branch on body content.
            let extras = Int(data.integer(in: UInt8(0)...UInt8(3)))
            for _ in 0..<extras {
                guard let name = data.element(of: [
                    HTTPField.Name.contentType,
                    .contentLength,
                    .contentEncoding,
                    .contentLanguage,
                    .contentLocation,
                ]) else { break }
                guard let value = data.element(of: [
                    "text/plain",
                    "application/octet-stream",
                    "text/plain; charset=utf-8",
                    "",
                    "0",
                    String(repeating: "x", count: 300),
                ]) else { break }
                fields[name] = value
            }

            parts.append(MultipartPart(headerFields: fields, body: body))
        }
        guard !parts.isEmpty else { return }

        // Multipart has no escaping mechanism, so a body containing the
        // delimiter produces a message that genuinely splits differently on the
        // way back. That breaks the fixed point for a reason belonging to the
        // format rather than to this library.
        //
        // What matters is *where* that is handled. Returning early here — the
        // first version of this target — threw away the whole execution, and a
        // fuzzer produces `--boundary123` inside a body far more often than
        // chance because it is all over the corpus. Coverage moved four edges in
        // 473,000 runs. So the write and the parse always happen, and only the
        // equality assertion is conditional.
        let smuggled = parts.contains { $0.body.containsSubsequence(boundaryBytes) }

        var writer = MemoryMultipartWriter<[UInt8]>(boundary: boundary)
        for part in parts { await writer.writePart(part) }
        await writer.finish()
        let serialized = writer.getResult()

        let parsed = try? MultipartParser<[UInt8]>(boundary: boundary).parse(serialized)

        // Beyond this point the fixed point applies.
        guard !smuggled else { return }

        guard let parsed else {
            fatalError("a message this library serialized does not parse back")
        }
        guard parsed.count == parts.count else {
            fatalError("serialized \(parts.count) parts, parsed back \(parsed.count)")
        }
        for (original, returned) in zip(parts, parsed) where original.body != returned.body {
            fatalError("a part body did not survive the round trip")
        }
    }
}

extension Collection where Element: Equatable {
    /// Whether `needle` appears anywhere in the collection.
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
