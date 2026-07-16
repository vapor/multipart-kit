import HTTPTypes
import MultipartKit
import Testing

@Suite("Streaming MultipartSection Tests")
struct StreamingMultipartSectionAsyncSequenceTests {
    /// Wraps a fixed array of sections in an `AsyncStream`.
    private func stream(
        _ sections: [MultipartSection<[UInt8]>]
    ) -> AsyncStream<MultipartSection<[UInt8]>> {
        AsyncStream { continuation in
            for section in sections { continuation.yield(section) }
            continuation.finish()
        }
    }

    /// bytes -> parts (`StreamingMultipartPartAsyncSequence`)
    /// then back through
    /// parts -> bytes (`StreamingMultipartSectionAsyncSequence`)
    private func roundTrip(
        _ input: [MultipartSection<[UInt8]>]
    ) async throws -> [MultipartSection<[UInt8]>] {
        let parts = StreamingMultipartPartAsyncSequence(backingSequence: stream(input))
        let sections = StreamingMultipartSectionAsyncSequence(parts: parts)
        var output: [MultipartSection<[UInt8]>] = []
        for try await section in sections { output.append(section) }
        return output
    }

    /// `MultipartSection` isn't `Equatable`, so normalize to a comparable token.
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

    @Test("Two parts round-trip to the same section framing")
    func roundTripsTwoParts() async throws {
        let input: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="a""#]),
            .bodyChunk([UInt8]("hello".utf8)),
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="b""#]),
            .bodyChunk([UInt8]("wor".utf8)), .bodyChunk([UInt8]("ld".utf8)),
            .boundary(end: true),
        ]

        #expect(try await tokens(roundTrip(input)) == tokens(input))
    }

    @Test("A single part round-trips")
    func roundTripsSinglePart() async throws {
        let input: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="only""#]),
            .bodyChunk([UInt8]("value".utf8)),
            .boundary(end: true),
        ]

        #expect(try await tokens(roundTrip(input)) == tokens(input))
    }

    @Test("Framing is emitted in order: leading boundary, headers, body, separators, final boundary")
    func emitsFramingInOrder() async throws {
        let input: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="a""#]),
            .bodyChunk([UInt8]("x".utf8)),
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="b""#]),
            .bodyChunk([UInt8]("y".utf8)),
            .boundary(end: true),
        ]

        // Pin the exact section order, not just round-trip symmetry.
        #expect(
            try await tokens(roundTrip(input)) == [
                .boundary(end: false),
                .headers([.contentDisposition: #"form-data; name="a""#]),
                .body([UInt8]("x".utf8)),
                .boundary(end: false),
                .headers([.contentDisposition: #"form-data; name="b""#]),
                .body([UInt8]("y".utf8)),
                .boundary(end: true),
            ]
        )
    }

    @Test("Multiple body chunks keep their boundaries through the round-trip")
    func preservesBodyChunkBoundaries() async throws {
        let input: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="text""#]),
            .bodyChunk([UInt8]("Lorem ".utf8)),
            .bodyChunk([UInt8]("ipsum ".utf8)),
            .bodyChunk([UInt8]("dolor".utf8)),
            .boundary(end: true),
        ]

        #expect(try await tokens(roundTrip(input)) == tokens(input))
    }

    @Test("Many parts round-trip")
    func roundTripsManyParts() async throws {
        let names = ["alpha", "beta", "gamma", "delta", "epsilon"]
        var input: [MultipartSection<[UInt8]>] = [.boundary(end: false)]
        for (index, name) in names.enumerated() {
            input.append(.headerFields([.contentDisposition: "form-data; name=\"\(name)\""]))
            input.append(.bodyChunk([UInt8](name.utf8)))
            input.append(.boundary(end: index == names.count - 1))
        }

        #expect(try await tokens(roundTrip(input)) == tokens(input))
    }

    @Test("Merged header sections collapse onto one part and round-trip as a single header section")
    func mergedHeadersRoundTrip() async throws {
        let input: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="file""#]),
            .headerFields([.contentType: "application/json"]),
            .bodyChunk([UInt8]("{}".utf8)),
            .boundary(end: true),
        ]

        // The two header sections become one part, so the output has a single merged
        // `.headerFields` section rather than two.
        #expect(
            try await tokens(roundTrip(input)) == [
                .boundary(end: false),
                .headers([
                    .contentDisposition: #"form-data; name="file""#,
                    .contentType: "application/json",
                ]),
                .body([UInt8]("{}".utf8)),
                .boundary(end: true),
            ]
        )
    }

    @Test("An empty part sequence emits only the terminating boundary")
    func emptyBackingEmitsFinalBoundary() async throws {
        // No parts upstream → the section stream still terminates the message.
        #expect(try await tokens(roundTrip([])) == [.boundary(end: true)])
    }
}
