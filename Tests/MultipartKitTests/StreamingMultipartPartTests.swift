import HTTPTypes
import MultipartKit
import Testing

@Suite("Streaming MultipartPart Tests")
struct StreamingMultipartPartTests {
    /// Wraps a fixed array of sections in an `AsyncStream` so it can back a
    /// `StreamingMultipartPartAsyncSequence`.
    private func stream(
        _ sections: [MultipartSection<[UInt8]>]
    ) -> AsyncStream<MultipartSection<[UInt8]>> {
        AsyncStream { continuation in
            for section in sections { continuation.yield(section) }
            continuation.finish()
        }
    }

    /// Drains a part's streamed body into a single buffer.
    private func collect<S: AsyncSequence>(_ body: S) async throws -> [UInt8] where S.Element == [UInt8] {
        var buffer: [UInt8] = []
        for try await chunk in body { buffer.append(contentsOf: chunk) }
        return buffer
    }

    @Test("Boundaries are handled")
    func partsWithBoundaries() async throws {
        let sections: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="a""#]),
            .bodyChunk([UInt8]("hello".utf8)),
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="b""#]),
            .bodyChunk([UInt8]("wor".utf8)), .bodyChunk([UInt8]("ld".utf8)),
            .boundary(end: true),
        ]

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        let part1 = try #require(try await iterator.next())
        #expect(part1.headerFields == [.contentDisposition: #"form-data; name="a""#])
        #expect(try await collect(part1.body) == [UInt8]("hello".utf8))

        let part2 = try #require(try await iterator.next())
        #expect(part2.headerFields == [.contentDisposition: #"form-data; name="b""#])
        #expect(try await collect(part2.body) == [UInt8]("world".utf8))

        try #require(try await iterator.next() == nil)
    }

    @Test("Single part with a single body chunk")
    func singlePart() async throws {
        let sections: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="only""#]),
            .bodyChunk([UInt8]("value".utf8)),
            .boundary(end: true),
        ]

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        let part = try #require(try await iterator.next())
        #expect(part.headerFields == [.contentDisposition: #"form-data; name="only""#])
        #expect(try await collect(part.body) == [UInt8]("value".utf8))
        try #require(try await iterator.next() == nil)
    }

    @Test("Multiple header field sections are merged onto a single part")
    func multipleHeaderFields() async throws {
        let sections: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="file""#]),
            .headerFields([.contentType: "application/json"]),
            .bodyChunk([UInt8]("{}".utf8)),
            .boundary(end: true),
        ]

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        let part = try #require(try await iterator.next())
        #expect(
            part.headerFields == [
                .contentDisposition: #"form-data; name="file""#,
                .contentType: "application/json",
            ]
        )
        #expect(try await collect(part.body) == [UInt8]("{}".utf8))
        try #require(try await iterator.next() == nil)
    }

    @Test("An empty upstream yields no parts")
    func emptyUpstream() async throws {
        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream([]))
        let iterator = sequence.makeAsyncIterator()
        try #require(try await iterator.next() == nil)
    }

    @Test("An upstream with only boundaries yields no parts")
    func onlyBoundaries() async throws {
        let sections: [MultipartSection<[UInt8]>] = [.boundary(end: false), .boundary(end: true)]
        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()
        try #require(try await iterator.next() == nil)
    }

    @Test("Consumes real parser output end-to-end")
    func endToEndWithParser() async throws {
        let boundary = "boundary123"
        let message = ArraySlice(
            """
            --\(boundary)\r
            Content-Disposition: form-data; name="first"\r
            \r
            hello\r
            --\(boundary)\r
            Content-Disposition: form-data; name="second"\r
            \r
            world\r
            --\(boundary)--
            """.utf8
        )

        let byteStream = AsyncStream<ArraySlice<UInt8>> { continuation in
            var offset = message.startIndex
            while offset < message.endIndex {
                let end = min(message.endIndex, message.index(offset, offsetBy: 8))
                continuation.yield(message[offset..<end])
                offset = end
            }
            continuation.finish()
        }

        var sections: [MultipartSection<ArraySlice<UInt8>>] = []
        for try await section in StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: byteStream) {
            sections.append(section)
        }

        let upstream = AsyncStream<MultipartSection<ArraySlice<UInt8>>> { continuation in
            for section in sections { continuation.yield(section) }
            continuation.finish()
        }

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: upstream)
        let iterator = sequence.makeAsyncIterator()

        let part1 = try #require(try await iterator.next())
        #expect(part1.headerFields[.contentDisposition] == #"form-data; name="first""#)
        var body1: [UInt8] = []
        for try await chunk in part1.body { body1.append(contentsOf: chunk) }
        #expect(body1 == [UInt8]("hello".utf8))

        let part2 = try #require(try await iterator.next())
        #expect(part2.headerFields[.contentDisposition] == #"form-data; name="second""#)
        var body2: [UInt8] = []
        for try await chunk in part2.body { body2.append(contentsOf: chunk) }
        #expect(body2 == [UInt8]("world".utf8))

        try #require(try await iterator.next() == nil)
    }

    @Test("Requesting the next part before draining the current body throws")
    func outOfOrderOnLaterPartThrows() async throws {
        let sections: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="a""#]),
            .bodyChunk([UInt8]("a".utf8)),
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="b""#]),
            .bodyChunk([UInt8]("b".utf8)),
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="c""#]),
            .bodyChunk([UInt8]("c".utf8)),
            .boundary(end: true),
        ]

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        // Consume part 1 correctly
        let part1 = try #require(try await iterator.next())
        #expect(try await collect(part1.body) == [UInt8]("a".utf8))

        // Take part 2 but skip its body, then reach for part 3
        _ = try #require(try await iterator.next())
        await #expect(throws: StreamingMultipartPartError.nextPartRequestedWhileStreamingPreviousBody) {
            _ = try await iterator.next()
        }
    }

    @Test("A part with an explicitly empty body streams zero bytes")
    func emptyBodyPartStreamsNoBytes() async throws {
        let sections: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="empty""#]),
            .bodyChunk([]),
            .boundary(end: true),
        ]

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        let part = try #require(try await iterator.next())
        #expect(part.headerFields == [.contentDisposition: #"form-data; name="empty""#])
        #expect(try await collect(part.body) == [])
        try #require(try await iterator.next() == nil)
    }

    @Test("A body delivered as many small chunks is reassembled in order")
    func bodySplitAcrossManyChunks() async throws {
        let chunks = ["Lorem ", "ipsum ", "dolor ", "sit ", "amet"]
        var sections: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="text""#]),
        ]
        for chunk in chunks { sections.append(.bodyChunk([UInt8](chunk.utf8))) }
        sections.append(.boundary(end: true))

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        let part = try #require(try await iterator.next())
        #expect(try await collect(part.body) == [UInt8](chunks.joined().utf8))
        try #require(try await iterator.next() == nil)
    }

    @Test("Many parts stream in order")
    func manyPartsStreamInOrder() async throws {
        let names = ["alpha", "beta", "gamma", "delta", "epsilon"]
        var sections: [MultipartSection<[UInt8]>] = [.boundary(end: false)]
        for (index, name) in names.enumerated() {
            sections.append(.headerFields([.contentDisposition: "form-data; name=\"\(name)\""]))
            sections.append(.bodyChunk([UInt8](name.utf8)))
            sections.append(.boundary(end: index == names.count - 1))
        }

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        var index = 0
        while let part = try await iterator.next() {
            #expect(part.headerFields[.contentDisposition] == "form-data; name=\"\(names[index])\"")
            #expect(try await collect(part.body) == [UInt8](names[index].utf8))
            index += 1
        }
        #expect(index == names.count)
    }

    @Test("Draining an already-finished body again just returns nil")
    func reDrainingAFinishedBodyReturnsNil() async throws {
        let sections: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="a""#]),
            .bodyChunk([UInt8]("a".utf8)),
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="b""#]),
            .bodyChunk([UInt8]("b".utf8)),
            .boundary(end: true),
        ]

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        let part1 = try #require(try await iterator.next())
        let body1 = part1.body.makeAsyncIterator()
        var collected: [UInt8] = []
        while let chunk = try await body1.next() { collected.append(contentsOf: chunk) }
        #expect(collected == [UInt8]("a".utf8))

        #expect(try await body1.next() == nil)
    }

    @Test("A stale body iterator must not steal the next part's bytes")
    func staleBodyIteratorDoesNotStealNextPart() async throws {
        let sections: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="a""#]),
            .bodyChunk([UInt8]("a1".utf8)), .bodyChunk([UInt8]("a2".utf8)),
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="b""#]),
            .bodyChunk([UInt8]("b1".utf8)),
            .boundary(end: true),
        ]

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        let part1 = try #require(try await iterator.next())
        let body1 = part1.body.makeAsyncIterator()
        var collected: [UInt8] = []
        while let chunk = try await body1.next() { collected.append(contentsOf: chunk) }
        #expect(collected == [UInt8]("a1a2".utf8))

        _ = try #require(try await iterator.next())

        let leaked = try await body1.next()
        #expect(leaked == nil)
    }

    @Test("A part with no body section should be surfaced, not merged forward")
    func partWithNoBodyIsSurfaced() async throws {
        let sections: [MultipartSection<[UInt8]>] = [
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="a""#]),  // empty part
            .boundary(end: false),
            .headerFields([.contentDisposition: #"form-data; name="b""#]),
            .bodyChunk([UInt8]("b".utf8)),
            .boundary(end: true),
        ]

        let sequence = StreamingMultipartPartAsyncSequence(backingSequence: stream(sections))
        let iterator = sequence.makeAsyncIterator()

        var count = 0
        while let part = try await iterator.next() {
            _ = try await collect(part.body)
            count += 1
        }
        #expect(count == 2)
    }
}
