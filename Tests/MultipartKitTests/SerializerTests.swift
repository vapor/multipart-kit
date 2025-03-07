#if canImport(Testing)
import HTTPTypes
import MultipartKit
import Testing

@Suite("Serializer Tests")
struct SerializerTests {
    @Test("Serialize Example")
    func serializeExample() async throws {
        let boundary = "boundary123"

        let example: [MultipartSection<ArraySlice<UInt8>>] = [
            .boundary(end: false),
            .headerFields(
                .init([
                    .init(name: .contentDisposition, value: "form-data; name=\"file\"; filename=\"hello.txt\""),
                    .init(name: .contentType, value: "text/plain"),
                ])),
            .bodyChunk(ArraySlice("Hello, world!".utf8)),
        ]

        let stream = makeSerializationStream(for: example)
        let sequence = MultipartSerializerAsyncSequence(
            boundary: boundary,
            backingSequence: stream
        )

        var serialized = ArraySlice<UInt8>()
        for try await part in sequence {
            serialized.append(contentsOf: part)
        }

        let expected = ArraySlice(
            """
            --boundary123\r
            Content-Disposition: form-data; name="file"; filename="hello.txt"\r
            Content-Type: text/plain\r
            \r
            Hello, world!\r
            --boundary123--\r\n
            """.utf8)
        #expect(serialized == expected)
    }

    @Test("Serialize Synchronously")
    func serializeSynchronously() async throws {
        let example: [MultipartPart] = [
            .init(
                headerFields: .init([
                    .init(name: .contentDisposition, value: "form-data; name=\"file\"; filename=\"hello.txt\""),
                    .init(name: .contentType, value: "text/plain"),
                ]),
                body: ArraySlice("Hello, world!".utf8)
            )
        ]

        let serialized: ArraySlice<UInt8> = MultipartSerializer(boundary: "boundary123").serialize(parts: example)
        let expected = ArraySlice(
            """
            --boundary123\r
            Content-Disposition: form-data; name="file"; filename="hello.txt"\r
            Content-Type: text/plain\r
            \r
            Hello, world!\r
            --boundary123--\r\n
            """.utf8)
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
#endif  // canImport(Testing)
