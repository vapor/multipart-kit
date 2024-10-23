import HTTPTypes
import Testing

@testable import MultipartKit

@Suite("Multipart Parser Tests")
struct MultipartParserTests {
    @Test("Basic header example parsing")
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
}
