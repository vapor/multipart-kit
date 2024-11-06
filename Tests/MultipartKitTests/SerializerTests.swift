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

        let serialized = try MultipartSerializer.serialize(parts: example, boundary: "boundary123")
    }
}
