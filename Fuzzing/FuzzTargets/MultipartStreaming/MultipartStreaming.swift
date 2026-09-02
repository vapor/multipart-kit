import Fuzzing
import MultipartKit

/// An `AsyncSequence` that yields pre-computed chunks, so the split points are
/// the fuzzer's to choose rather than a fixed size.
private struct ChunkSequence: AsyncSequence, Sendable {
    typealias Element = [UInt8]
    let chunks: [[UInt8]]

    struct AsyncIterator: AsyncIteratorProtocol {
        var remaining: ArraySlice<[UInt8]>
        mutating func next() async -> [UInt8]? {
            remaining.isEmpty ? nil : remaining.removeFirst()
        }
    }

    func makeAsyncIterator() -> AsyncIterator { .init(remaining: chunks[...]) }
}

let fuzzTargets: @Sendable () -> Void = {
    // The streaming parser, fed in several pieces rather than one.
    //
    // That is the entire point of this target. A streaming parser's bugs live
    // at the boundaries between reads — a header split across two chunks, a
    // multipart boundary split in half, a CRLF with its halves in different
    // buffers — and none of them are reachable if the whole message arrives in
    // a single append. The split points come from the input so the fuzzer can
    // move them, which is what turns them into something coverage can guide.
    FuzzTarget.structuredAsync("MultipartStreaming") { data in
        var data = data
        // Drawn from a set rather than fuzzed freely, for two reasons. A boundary
        // that never matches anything in the body means the parser is only ever
        // exercised on its "found nothing" path. And holding the draw to a fixed
        // 8 bytes off the back leaves the whole front of the input as the body,
        // so a seed is a real multipart message on disk rather than something
        // reverse-engineered out of the provider's draw order.
        //
        // The illegal ones are in the set on purpose: RFC 2046 constrains what a
        // boundary may contain, and the question is what this parser does when a
        // client ignores that.
        let boundary = data.element(of: [
            "boundary123",
            "",                       // empty
            "-",                      // collides with the leading dashes
            "--",
            "\r\n",                   // a boundary that is itself a line break
            String(repeating: "a", count: 200),
        ]) ?? "boundary123"

        var chunks: [[UInt8]] = []
        while !data.isEmpty && chunks.count < 64 {
            let chunk = data.chunk()
            if chunk.isEmpty { break }
            chunks.append(chunk)
        }
        // Whatever is left goes in as a final chunk, so no input is wasted.
        let tail = data.remainingBytes()
        if !tail.isEmpty { chunks.append(tail) }
        guard !chunks.isEmpty else { return }

        let sequence = StreamingMultipartParserAsyncSequence(
            boundary: boundary,
            buffer: ChunkSequence(chunks: chunks)
        )

        do {
            for try await section in sequence {
                switch section {
                case .headerFields(let fields):
                    for field in fields { _ = field.value }
                case .bodyChunk(let chunk):
                    _ = chunk.count
                case .boundary:
                    break
                }
            }
        } catch {
            // Every malformed message is a thrown MultipartParserError. Only a
            // trap reaches libFuzzer.
        }
    }
}
