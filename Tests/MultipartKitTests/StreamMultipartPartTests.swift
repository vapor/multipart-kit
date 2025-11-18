import MultipartKit
import Testing

@Suite("Stream MultipartPart Tests")
struct StreamMultipartPartTests {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func test() async throws {
        let sections: [MultipartSection] = [
            .headerFields([.contentDisposition: #"form-data; name="name""#]), .bodyChunk([UInt8]("2".utf8)),
            .bodyChunk([UInt8]("4".utf8)), .headerFields([.contentDisposition: #"form-data; name="info""#]),
            .bodyChunk([UInt8]("{".utf8)), .bodyChunk([UInt8]("}".utf8)),
        ]

        let upstream = AsyncStream<MultipartSection> { continuation in
            var it = sections.makeIterator()
            while let section = it.next() {
                continuation.yield(section)
            }
            continuation.finish()
        }
        let sequence = StreamMultipartPartAsyncSequence(backingSequence: upstream)
        let iterator = sequence.makeAsyncIterator()

        let part1 = try #require(try await iterator.next())
        #expect(part1.headerFields == [.contentDisposition: #"form-data; name="name""#])
        var body1: [UInt8] = []
        for try await chunk in part1.body { body1.append(contentsOf: chunk) }

        let part2 = try #require(try await iterator.next())
        #expect(part2.headerFields == [.contentDisposition: #"form-data; name="info""#])
        var body2: [UInt8] = []
        for try await chunk in part2.body { body2.append(contentsOf: chunk) }

        try #require(try await iterator.next() == nil)
    }
}
