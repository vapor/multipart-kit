#if canImport(Testing)
import MultipartKit
import Testing
import HTTPTypes

@Suite("Writer Tests")
struct WriterTests {
    @Test("Write Example")
    func writeExample() async throws {
        let boundary = "boundary123"

        let example = [
            MultipartPart(
                headerFields: [
                    .contentDisposition: "form-data; name=\"file\"; filename=\"hello.txt\"",
                    .contentType: "text/plain",
                ],
                body: ArraySlice("Hello, world!".utf8)
            ),
            MultipartPart(
                headerFields: [
                    .contentDisposition: "form-data; name=\"file\"; filename=\"goodbye.txt\"",
                    .contentType: "text/plain",
                ],
                body: ArraySlice("Goodbye, world!".utf8)
            ),
        ]

        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: boundary)

        for part in example {
            try await writer.writePart(part)
        }

        try await writer.finish()

        let expected = ArraySlice(
            """
            --boundary123\r
            Content-Disposition: form-data; name="file"; filename="hello.txt"\r
            Content-Type: text/plain\r
            \r
            Hello, world!\r
            --boundary123\r
            Content-Disposition: form-data; name="file"; filename="goodbye.txt"\r
            Content-Type: text/plain\r
            \r
            Goodbye, world!\r
            --boundary123--\r\n
            """.utf8
        )

        #expect(writer.getResult() == expected)
    }

    @Test("Write through sequence")
    func writeSequenceExample() async throws {
        let boundary = "boundary123"

        let example: [MultipartSection<ArraySlice<UInt8>>] = [
            .boundary(end: false),
            .headerFields(
                [
                    .contentDisposition: "form-data; name=\"file\"; filename=\"hello.txt\"",
                    .contentType: "text/plain",
                ]
            ),
            .bodyChunk(ArraySlice("Hello, world!".utf8)),
            .boundary(end: false),
            .headerFields(
                [
                    .contentDisposition: "form-data; name=\"file\"; filename=\"goodbye.txt\"",
                    .contentType: "text/plain",
                ]
            ),
            .bodyChunk(ArraySlice("Goodbye, world!".utf8)),
            .boundary(end: true),

        ]

        let stream = makeSerializationStream(for: example)
        let sequence = StreamingMultipartWriterAsyncSequence(
            backingSequence: stream,
            boundary: boundary,
            outboundBody: ArraySlice<UInt8>.self
        )

        var serialized = ArraySlice<UInt8>()
        for try await section in sequence {
            serialized.append(contentsOf: section)
        }

        let expected = ArraySlice(
            """
            --boundary123\r
            Content-Disposition: form-data; name="file"; filename="hello.txt"\r
            Content-Type: text/plain\r
            \r
            Hello, world!\r
            --boundary123\r
            Content-Disposition: form-data; name="file"; filename="goodbye.txt"\r
            Content-Type: text/plain\r
            \r
            Goodbye, world!\r
            --boundary123--\r\n
            """.utf8
        )

        #expect(serialized == expected)
    }

    @Test("Writing boundary")
    func writeBoundary() async throws {
        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: "test")

        try await writer.writeBoundary()
        let result1 = writer.getResult()
        #expect(result1 == ArraySlice("--test\r\n".utf8))

        try await writer.writeBoundary(end: true)
        let result2 = writer.getResult()
        #expect(result2 == ArraySlice("--test--\r\n".utf8))
    }

    @Test("Writing header fields")
    func testWriteHeaders() async throws {
        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: "test")

        let headers: HTTPFields = [
            .contentType: "text/plain",
            .contentDisposition: "form-data; name=\"test\"",
        ]

        try await writer.writeHeaders(headers)
        let result = writer.getResult()

        let resultString = String(decoding: result, as: UTF8.self)
        #expect(resultString.contains("Content-Type: text/plain\r\n"))
        #expect(resultString.contains("Content-Disposition: form-data; name=\"test\"\r\n"))
        #expect(resultString.hasSuffix("\r\n\r\n"))
    }

    @Test("Writing body chunks")
    func writeBodyChunks() async throws {
        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: "test")

        try await writer.writeBodyChunk(ArraySlice("chunk1".utf8))
        let result1 = writer.getResult()
        #expect(result1 == ArraySlice("chunk1".utf8))

        let chunks = [
            ArraySlice("chunk1".utf8),
            ArraySlice("chunk2".utf8),
            ArraySlice("chunk3".utf8),
        ]
        try await writer.writeBodyChunks(chunks)
        let result2 = writer.getResult()
        #expect(result2 == ArraySlice("chunk1chunk2chunk3\r\n".utf8))

    }

    @Test("Empty boundary handling")
    func testEmptyBoundary() async throws {
        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: "")
        try await writer.writeBoundary()
        let result = writer.getResult()
        #expect(result == ArraySlice("--\r\n".utf8))
    }

    @Test("Large parts handling")
    func testLargeParts() async throws {
        let boundary = "test"
        let largeBody = ArraySlice(Array(repeating: UInt8(65), count: 1 << 20))  // 1MB of 'A'

        let part = MultipartPart(
            headerFields: [.contentType: "application/octet-stream"],
            body: largeBody
        )

        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: boundary)
        try await writer.writePart(part)
        try await writer.finish()

        let result = writer.getResult()
        #expect(result.count > largeBody.count)
    }

    @Test("Getting result clears buffer")
    func getResultClearsBuffer() async throws {
        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: "test")

        try await writer.writeBoundary()
        let result1 = writer.getResult()
        #expect(!result1.isEmpty)

        let result2 = writer.getResult()
        #expect(result2.isEmpty)
    }

    @Test("Unicode in headers")
    func testUnicodeHeaders() async throws {
        var writer = MemoryMultipartWriter<ArraySlice<UInt8>>(boundary: "test")

        let headers: HTTPFields = [
            .contentDisposition: "form-data; name=\"tëst\"; filename=\"filé.txt\""
        ]

        try await writer.writeHeaders(headers)
        let result = writer.getResult()

        let resultString = String(decoding: result, as: UTF8.self)
        #expect(resultString.contains("tëst"))
        #expect(resultString.contains("filé.txt"))
    }

    @Test("Create Boundary")
    func createBoundary() {
        let boundary = "boundary123"

        let formattedBoundary = makeBoundaryBytes(boundary, as: [UInt8].self)
        let expectedBoundary: [UInt8] = [
            45, 45, 98, 111, 117, 110, 100, 97, 114, 121, 49, 50, 51, 13, 10,
        ]
        #expect(formattedBoundary == expectedBoundary)

        let formattedEndBoundary = makeBoundaryBytes(boundary, end: true, as: [UInt8].self)
        let expectedEndBoundary: [UInt8] = [
            45, 45, 98, 111, 117, 110, 100, 97, 114, 121, 49, 50, 51, 45, 45, 13, 10,
        ]
        #expect(formattedEndBoundary == expectedEndBoundary)
    }

    @Test("BufferedMultipartWriter buffers until capacity")
    func testBufferedWriterBuffering() async throws {
        let mockWriter = MockMultipartWriter<ArraySlice<UInt8>>(boundary: "test-boundary")

        var writer = BufferedMultipartWriter(
            boundary: "test-boundary",
            bufferCapacity: 100,
            underlyingWriter: mockWriter
        )

        try await writer.write(bytes: ArraySlice("This is a small write".utf8))
        #expect(mockWriter.writeCallCount == 0)

        let largeData = ArraySlice(Array(repeating: UInt8(65), count: 150))
        try await writer.write(bytes: largeData)
        let countAfterFirstWrite = mockWriter.writeCallCount

        #expect(mockWriter.writeCallCount > 0)
        #expect(mockWriter.lastWrittenData != nil)

        try await writer.finish(writingEndBoundary: false)

        #expect(mockWriter.writeCallCount == countAfterFirstWrite)
    }

    @Test("BufferedMultipartWriter forwards operations to underlying writer")
    func testBufferedWriterOperations() async throws {
        let mockWriter = MockMultipartWriter<ArraySlice<UInt8>>(boundary: "test-boundary")

        var writer = BufferedMultipartWriter(
            boundary: "test-boundary",
            bufferCapacity: 1024,
            underlyingWriter: mockWriter
        )

        let part = MultipartPart(
            headerFields: [
                .contentDisposition: "form-data; name=\"test\"",
                .contentType: "text/plain",
            ],
            body: ArraySlice("Test content".utf8)
        )

        try await writer.writePart(part)
        try await writer.finish()

        #expect(mockWriter.boundary == "test-boundary")
    }

    @Test("BufferedMultipartWriter correctly flushes data")
    func testBufferedWriterFlush() async throws {
        let mockWriter = MockMultipartWriter<ArraySlice<UInt8>>(boundary: "test-boundary")

        var writer = BufferedMultipartWriter(
            boundary: "test-boundary",
            bufferCapacity: 20,
            underlyingWriter: mockWriter
        )

        try await writer.write(bytes: ArraySlice("First chunk of data".utf8))
        try await writer.write(bytes: ArraySlice("Second chunk of data".utf8))
        try await writer.write(bytes: ArraySlice("Third chunk of data".utf8))
        try await writer.finish()

        #expect(mockWriter.writeCallCount > 1)
    }

    @Test("BufferedMultipartWriter with large multipart message")
    func testBufferedWriterLargeMessage() async throws {
        let mockWriter = MockMultipartWriter<ArraySlice<UInt8>>(boundary: "test-boundary")

        var writer = BufferedMultipartWriter(
            boundary: "test-boundary",
            bufferCapacity: 256,
            underlyingWriter: mockWriter
        )

        let largeBody = ArraySlice(Array(repeating: UInt8(65), count: 500))

        let part = MultipartPart(
            headerFields: [.contentType: "application/octet-stream"],
            body: largeBody
        )

        try await writer.writePart(part)
        try await writer.finish()

        #expect(mockWriter.writeCallCount > 1)
    }

    @Test("BufferedMultipartWriter buffers and flushes as expected")
    func testBufferedWriterBufferingAndFlushing() async throws {
        final class CountingWriter: MultipartWriter, @unchecked Sendable {
            typealias OutboundBody = ArraySlice<UInt8>
            var writes: [[UInt8]] = []
            let boundary: String
            init(boundary: String) { self.boundary = boundary }
            func write(bytes: some Collection<UInt8> & Sendable) async throws {
                writes.append(Array(bytes))
            }
            func finish() async throws {}
        }

        let countingWriter = CountingWriter(boundary: "boundary")
        var writer = BufferedMultipartWriter(
            boundary: "boundary",
            bufferCapacity: 10,
            underlyingWriter: countingWriter
        )

        // Write less than bufferCapacity, should not flush yet
        try await writer.write(bytes: ArraySlice("12345".utf8))
        #expect(countingWriter.writes.isEmpty)

        // Write enough to exceed bufferCapacity, should flush
        try await writer.write(bytes: ArraySlice("67890".utf8))
        #expect(!countingWriter.writes.isEmpty)

        // Write more, should buffer again
        let writesAfterFlush = countingWriter.writes.count
        try await writer.write(bytes: ArraySlice("abc".utf8))
        #expect(countingWriter.writes.count == writesAfterFlush)

        try await writer.finish(writingEndBoundary: false)
        #expect(countingWriter.writes.count > writesAfterFlush)

        // Check that all data is present in order
        let allData = countingWriter.writes.flatMap { $0 }
        let expected = Array("1234567890abc".utf8)
        #expect(allData == expected)
    }

    @Test("BufferedMultipartWriter produces correct multipart output")
    func testBufferedWriterProducesCorrectMultipart() async throws {
        let boundary = "buffered-boundary"
        let part1 = MultipartPart(
            headerFields: [
                .contentDisposition: "form-data; name=\"foo\"",
                .contentType: "text/plain",
            ],
            body: ArraySlice("hello".utf8)
        )
        let part2 = MultipartPart(
            headerFields: [
                .contentDisposition: "form-data; name=\"bar\"",
                .contentType: "text/plain",
            ],
            body: ArraySlice("world".utf8)
        )

        let underlyingWriter = MockMultipartWriter<ArraySlice<UInt8>>(boundary: boundary)
        var bufferedWriter = BufferedMultipartWriter(
            boundary: boundary,
            bufferCapacity: 8,
            underlyingWriter: underlyingWriter
        )

        try await bufferedWriter.writePart(part1)
        try await bufferedWriter.writePart(part2)
        try await bufferedWriter.finish()

        let expected = ArraySlice(
            """
            --buffered-boundary\r
            Content-Disposition: form-data; name="foo"\r
            Content-Type: text/plain\r
            \r
            hello\r
            --buffered-boundary\r
            Content-Disposition: form-data; name="bar"\r
            Content-Type: text/plain\r
            \r
            world\r
            --buffered-boundary--\r\n
            """.utf8
        )

        #expect(underlyingWriter.buffer == expected)
    }

    private final class MockMultipartWriter<OutboundBody: MultipartPartBodyElement>: MultipartWriter, @unchecked Sendable {
        let boundary: String
        private(set) var buffer: OutboundBody
        private(set) var writeCallCount = 0
        private(set) var lastWrittenData: OutboundBody?

        init(boundary: String) {
            self.boundary = boundary
            self.buffer = .init()
        }

        func write(bytes: some Collection<UInt8> & Sendable) async throws {
            writeCallCount += 1
            buffer.append(contentsOf: bytes)
            if let typedBytes = bytes as? OutboundBody {
                lastWrittenData = typedBytes
            } else {
                var buffer = OutboundBody()
                buffer.append(contentsOf: bytes)
                lastWrittenData = buffer
            }
        }

        func finish() async throws {}
    }

    private func makeSerializationStream<Body: MultipartPartBodyElement>(
        for message: [MultipartSection<Body>]
    ) -> AsyncStream<MultipartSection<Body>> {
        .init { continuation in
            for section in message {
                continuation.yield(section)
            }
            continuation.finish()
        }
    }
}
#endif
