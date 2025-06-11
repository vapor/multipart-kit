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

        var writer = BufferedMultipartWriter<ArraySlice<UInt8>>(boundary: boundary)

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
