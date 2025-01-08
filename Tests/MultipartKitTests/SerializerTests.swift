import HTTPTypes
import MultipartKit
import Testing

@Suite("Serializer Tests")
struct SerializerTests {
    @Test("Serialize Example")
    func serialize() async throws {
        let example: [MultipartPart] = [
            .init(
                headerFields: .init([
                    .init(name: .contentDisposition, value: "form-data; name=\"file\"; filename=\"hello.txt\""),
                    .init(name: .contentType, value: "text/plain"),
                ]),
                body: ArraySlice("Hello, world!".utf8)
            )
        ]

        let serialized: ArraySlice<UInt8> = try MultipartSerializer(boundary: "boundary123").serialize(parts: example)
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
}
