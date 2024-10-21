import HTTPTypes
import MultipartKit
import Testing

@Suite("Multipart Parser Tests")
struct MultipartParserTests {
    @Test("Basic header example parsing")
    func parseBasicExample() async throws {
        let boundary = "--boundary123"
        let message = """
            --boundary123\r
            Content-Type: text/plain\r
            Content-Disposition: form-data; name="field1"\r
            \r
            value1\r
            --boundary123\r
            Content-Type: text/plain\r
            Content-Disposition: form-data; name="field2"\r
            \r
            value2\r
            --boundary123--\r
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
            .init(name: .contentType, value: "text/plain"),
            .init(name: .contentDisposition, value: "form-data; name=\"field1\""),
//            .init(name: .contentDisposition, value: "form-data; name=\"field2\""),
//            .init(name: .contentType, value: "text/plain"),
        ]

        for part in parts {
            if case .headerField(let field) = part {
                #expect(field == expectedFields.removeFirst())
            }
        }
    }
}
