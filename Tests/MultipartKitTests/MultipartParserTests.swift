import HTTPTypes
import Testing

@testable import MultipartKit

@Suite("Multipart Parser Tests")
struct MultipartParserTests {
    @Test("Parse Basic Example")
    func parseBasicExample() async throws {
        let boundary = "--boundary123"
        let message = """
            \(boundary)\r
            Content-Disposition: form-data; name="id"\r
            Content-Type: text/plain\r
            \r
            123e4567-e89b-12d3-a456-426655440000\r
            \(boundary)--
            """

        let uint8Slice = ArraySlice(message.utf8)
        let stream = AsyncStream<ArraySlice<UInt8>> { continuation in
            var offset = uint8Slice.startIndex
            while offset < uint8Slice.endIndex {
                let endIndex = min(uint8Slice.endIndex, offset + 16)
                continuation.yield(uint8Slice[offset..<endIndex])
                offset = endIndex
            }
            continuation.finish()
        }
        let sequence = MultipartParseSequence(boundary: boundary, buffer: stream)

        var parts: [MultipartPart] = []
        for try await part in sequence {
            parts.append(part)
        }

        var expectedFields: [HTTPField] = [
            .init(name: .contentDisposition, value: "form-data; name=\"id\""),
            .init(name: .contentType, value: "text/plain"),
        ]

        for part in parts {
            switch part {
            case .headerField(let field):
                #expect(field == expectedFields.removeFirst())
            case .bodyChunk(let chunk):
                #expect(String(decoding: chunk, as: UTF8.self) == "123e4567-e89b-12d3-a456-426655440000")
            case .boundary: break
            }
        }
    }

    @Test("Parse Complex Example")
    func parseComplexExample() async throws {
        let boundary = "--boundary123"
        let message = """
            \(boundary)\r
            Content-Disposition: form-data; name="id"\r
            Content-Type: text/plain\r
            \r
            123e4567-e89b-12d3-a456-426655440000\r
            \(boundary)\r
            Content-Disposition: form-data; name="address"\r
            Content-Type: application/json\r
            \r
            {\r
            "street": "3, Garden St",\r
            "city": "Hillsbery, UT"\r
            }\r
            \(boundary)\r
            Content-Disposition: form-data; name="profileImage"; filename="image1.png"\r
            Content-Type: application/octet-stream\r
            \r
            content of profile picture file\r
            \(boundary)--
            """

        let uint8Slice = ArraySlice(message.utf8)
        let stream = AsyncStream<ArraySlice<UInt8>> { continuation in
            var offset = uint8Slice.startIndex
            while offset < uint8Slice.endIndex {
                let endIndex = min(uint8Slice.endIndex, offset + 16)
                continuation.yield(uint8Slice[offset..<endIndex])
                offset = endIndex
            }
            continuation.finish()
        }
        let sequence = MultipartParseSequence(boundary: boundary, buffer: stream)

        var parts: [MultipartPart] = []
        for try await part in sequence {
            parts.append(part)
        }

        var expectedFields: [HTTPField] = [
            .init(name: .contentDisposition, value: "form-data; name=\"id\""),
            .init(name: .contentType, value: "text/plain"),
            .init(name: .contentDisposition, value: "form-data; name=\"address\""),
            .init(name: .contentType, value: "application/json"),
            .init(name: .contentDisposition, value: "form-data; name=\"profileImage\"; filename=\"image1.png\""),
            .init(name: .contentType, value: "application/octet-stream"),
        ]

        var expectedBodyParts: [ArraySlice<UInt8>] = [
            "123e4567-e89b-12d3-a456-426655440000",
            "{",
            "\"street\": \"3, Garden St\",",
            "\"city\": \"Hillsbery, UT\"",
            "}",
            "content of profile picture file",
        ].map { ArraySlice($0.utf8) }

        for part in parts {
            switch part {
            case .headerField(let field):
                #expect(field == expectedFields.removeFirst())
            case .bodyChunk(let chunk):
                #expect(chunk == expectedBodyParts.removeFirst())
            case .boundary: break
            }
        }

    }
}
