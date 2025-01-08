import HTTPTypes
import MultipartKit
import Testing

@Suite("Parser Tests")
struct ParserTests {
    @Test("Parse Example")
    func parseExample() async throws {
        let boundary = "boundary123"
        var message = ArraySlice(
            """
            --\(boundary)\r
            Content-Disposition: form-data; name="id"\r
            Content-Type: text/plain\r
            \r
            123e4567-e89b-12d3-a456-426655440000\r
            --\(boundary)\r
            Content-Disposition: form-data; name="address"\r
            Content-Type: application/json\r
            \r
            {\r
            "street": "3, Garden St",\r
            "city": "Hillsbery, UT"\r
            }\r
            --\(boundary)\r
            Content-Disposition: form-data; name="profileImage"; filename="image1.png"\r
            Content-Type: image/png\r
            \r\n
            """.utf8)
        message.append(contentsOf: pngData)
        message.append(contentsOf: "\r\n--\(boundary)--".utf8)

        let stream = makeParsingStream(for: message)
        let sequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: stream)

        var parts: [MultipartSection<ArraySlice<UInt8>>] = []
        for try await part in sequence {
            parts.append(part)
        }

        let expectedFields: HTTPFields = [
            .contentDisposition: "form-data; name=\"id\"",
            .contentType: "text/plain",
            .contentDisposition: "form-data; name=\"address\"",
            .contentType: "application/json",
            .contentDisposition: "form-data; name=\"profileImage\"; filename=\"image1.png\"",
            .contentType: "image/png",
        ]

        var expectedBodies: ArraySlice<UInt8> = []
        expectedBodies.append(contentsOf: "123e4567-e89b-12d3-a456-426655440000".utf8)
        expectedBodies.append(
            contentsOf: """
                {\r
                "street": "3, Garden St",\r
                "city": "Hillsbery, UT"\r
                }
                """.utf8)
        expectedBodies.append(contentsOf: pngData)

        var actualBodies: ArraySlice<UInt8> = []
        var actualFields: HTTPFields = [:]

        for part in parts {
            switch part {
            case .headerFields(let field):
                actualFields.append(contentsOf: field)
            case .bodyChunk(let chunk):
                actualBodies.append(contentsOf: chunk)
            case .boundary: break
            }
        }

        #expect(actualFields == expectedFields)
        #expect(actualBodies == expectedBodies)
    }

    @Test("Parse Collated Parts")
    func parseCollatedParts() async throws {
        let boundary = "boundary123"
        var message = ArraySlice(
            """
            --\(boundary)\r
            Content-Disposition: form-data; name="profileImage"; filename="image1.png"\r
            Content-Type: image/png\r
            \r\n
            """.utf8)
        message.append(contentsOf: pngData)
        message.append(contentsOf: "\r\n--\(boundary)--".utf8)

        let stream = makeParsingStream(for: message)
        let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: stream)

        var parts: [MultipartSection<ArraySlice<UInt8>>] = []
        for try await part in sequence {
            parts.append(part)
        }

        #expect(
            parts == [
                .headerFields([
                    .contentDisposition: "form-data; name=\"profileImage\"; filename=\"image1.png\"",
                    .contentType: "image/png",
                ]),
                .bodyChunk(ArraySlice(pngData)),
            ])
    }

    @Test("Parse Synchronously")
    func parseSynchronously() async throws {
        let boundary = "boundary123"
        let message = """
            --\(boundary)\r
            Content-Disposition: form-data; name="id"\r
            Content-Type: text/plain\r
            \r
            123e4567-e89b-12d3-a456-426655440000\r
            --\(boundary)--
            """

        let parts = try MultipartParser<[UInt8]>(boundary: boundary)
            .parse([UInt8](message.utf8))

        #expect(parts.count == 1)
        #expect(
            parts[0].headerFields == [
                .contentDisposition: "form-data; name=\"id\"",
                .contentType: "text/plain",
            ])
        #expect(parts[0].body == Array("123e4567-e89b-12d3-a456-426655440000".utf8))
    }

    @Test("Parse Corrupted Message")
    func parseCorruptedMessage() async throws {
        let boundary = "boundary123"
        let message = ArraySlice(
            """
            --\(boundary)\r
            Content-Disp
            """.utf8
        )

        #expect(throws: MultipartMessageError.unexpectedEndOfFile) {
            _ = try MultipartParser<[UInt8]>(boundary: boundary)
                .parse([UInt8](message))
        }

        let stream = makeParsingStream(for: message)
        var iterator = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: stream).makeAsyncIterator()

        await #expect(throws: MultipartMessageError.unexpectedEndOfFile) {
            while (try await iterator.next()) != nil {}
        }
    }

    @Test("Parse Message with Invalid Header Name")
    func parseInvalidHeader() async throws {
        let boundary = "boundary123"
        let message = ArraySlice(
            """
            --\(boundary)\r
            Content-Typ€: text/plain\r
            \r
            --\(boundary)--\r\n
            """.utf8
        )

        #expect(throws: MultipartParserError.invalidHeader(reason: "Invalid header name")) {
            _ = try MultipartParser<[UInt8]>(boundary: boundary)
                .parse([UInt8](message))
        }

        let stream = makeParsingStream(for: message)
        var iterator = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: stream).makeAsyncIterator()

        await #expect(throws: MultipartParserError.invalidHeader(reason: "Invalid header name")) {
            while (try await iterator.next()) != nil {}
        }
    }

    @Test("Parse non-ASCII header")
    func parseNonASCIIHeader() async throws {
        let filename = "Non-ASCII filé namé.txt"
        let data = ArraySlice(
            """
            ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
            Content-Disposition: form-data; name="test"; filename="\(filename)"\r
            \r
            eqw-dd-sa----123;1[234\r
            ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r\n
            """.utf8)

        let stream = makeParsingStream(for: data)
        let sequence = StreamingMultipartParserAsyncSequence(boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn", buffer: stream)

        for try await part in sequence {
            if case let .headerFields(fields) = part,
                let contentDispositionField = fields.first(where: { $0.name == .contentDisposition })
            {
                #expect(contentDispositionField.value.contains(filename))
            }
        }
    }

    @Test("Parse Message Missing Final Boundary")
    func parseMissingFinalBoundary() async throws {
        let boundary = "boundary123"
        let message = ArraySlice(
            """
            --\(boundary)\r
            Content-Disposition: form-data; name="id"\r
            Content-Type: text/plain\r
            \r
            123e4567-e89b-12d3-a456-426655440000\r
            """.utf8
        )

        #expect(throws: MultipartMessageError.unexpectedEndOfFile) {
            _ = try MultipartParser<[UInt8]>(boundary: boundary)
                .parse([UInt8](message))
        }

        let stream = makeParsingStream(for: message)
        var iterator = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: stream).makeAsyncIterator()

        await #expect(throws: MultipartMessageError.unexpectedEndOfFile) {
            while (try await iterator.next()) != nil {}
        }
    }

    private func makeParsingStream<Body: MultipartPartBodyElement>(for message: Body) -> AsyncStream<Body.SubSequence>
    where Body.SubSequence: Sendable {
        AsyncStream<Body.SubSequence> { continuation in
            var offset = message.startIndex
            while offset < message.endIndex {
                let endIndex = min(message.endIndex, message.index(offset, offsetBy: 16))
                continuation.yield(message[offset..<endIndex])
                offset = endIndex
            }
            continuation.finish()
        }
    }

    private let pngData: [UInt8] = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x3C, 0x08, 0x02, 0x00, 0x00, 0x00, 0xE9, 0x14, 0x0D,
        0x01, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73, 0x00, 0x00, 0x0E, 0xC4, 0x00, 0x00, 0x0E,
        0xC4, 0x01, 0x95, 0x2B, 0x0E, 0x1B, 0x00, 0x00, 0x01, 0x3B, 0x49, 0x44, 0x41, 0x54, 0x48, 0x89,
        0xB5, 0x96, 0xCB, 0x16, 0x83, 0x30, 0x08, 0x44, 0xA1, 0xC7, 0xFF, 0xFF, 0x65, 0xBA, 0xD0, 0x26,
        0x86, 0xD7, 0x40, 0xAC, 0x59, 0xF4, 0xB4, 0x54, 0xB8, 0x30, 0x21, 0x44, 0x16, 0x11, 0xDA, 0x5D,
        0x1F, 0x6B, 0x62, 0xE6, 0xF1, 0x69, 0xED, 0x8B, 0xE5, 0x09, 0xF9, 0x0A, 0x36, 0x42, 0xA8, 0xF0,
        0x79, 0xE8, 0x1E, 0x59, 0x85, 0x66, 0x15, 0xFE, 0x15, 0xB2, 0x55, 0x8B, 0x54, 0xCD, 0xF6, 0x89,
        0x97, 0xC9, 0x56, 0x6A, 0x11, 0x39, 0xBF, 0x03, 0x32, 0x4C, 0xCF, 0x4A, 0x38, 0x2C, 0xAC, 0xA4,
        0xBE, 0x67, 0x01, 0x2B, 0xC2, 0x0A, 0xB9, 0x9B, 0x77, 0xB5, 0xB0, 0xD2, 0xB9, 0xD7, 0x33, 0xAE,
        0xD5, 0xB6, 0x8D, 0x0A, 0x3A, 0xC9, 0xF7, 0xC4, 0xEA, 0x64, 0x76, 0x77, 0x0F, 0x46, 0x99, 0x6A,
        0x17, 0x1D, 0x1A, 0xE4, 0x28, 0x8A, 0xAA, 0xFF, 0x1F, 0xC3, 0x20, 0x27, 0x8F, 0x86, 0x51, 0x9D,
        0xE3, 0xB4, 0x5E, 0x43, 0xF0, 0x1C, 0x9B, 0x1C, 0xD2, 0xB6, 0x60, 0x0B, 0x96, 0xD9, 0x19, 0xBD,
        0x79, 0x7B, 0x33, 0xB3, 0xBF, 0xCF, 0x75, 0xF2, 0xD5, 0x9E, 0xB9, 0x9B, 0x3A, 0xA4, 0xEA, 0x01,
        0xFD, 0x1F, 0xC4, 0x2E, 0x25, 0x24, 0x64, 0x28, 0xE7, 0x72, 0xAA, 0xF2, 0x7D, 0x76, 0xEE, 0xAA,
        0x0D, 0xF2, 0x58, 0x87, 0xEB, 0x56, 0x5C, 0xF8, 0x48, 0x26, 0xFC, 0x83, 0xD6, 0x99, 0x56, 0x74,
        0x3B, 0xBD, 0x4A, 0xC3, 0x20, 0xDA, 0xC5, 0xA9, 0x36, 0x1C, 0xBA, 0x9B, 0x64, 0xFA, 0xB5, 0x1A,
        0xB8, 0x9F, 0x8B, 0xD8, 0xE9, 0x0C, 0xB1, 0xA1, 0x73, 0xD6, 0xF7, 0x08, 0xBE, 0x73, 0xCB, 0xCC,
        0x25, 0x22, 0xDB, 0x03, 0xF4, 0xD1, 0xE8, 0xDD, 0x4D, 0xF8, 0x21, 0xB9, 0xB2, 0x97, 0x35, 0x72,
        0x6F, 0xDC, 0x43, 0x2C, 0xDC, 0x88, 0xC6, 0x00, 0xB4, 0xA9, 0x39, 0xED, 0x7E, 0x27, 0xE7, 0x79,
        0x1E, 0xEA, 0x77, 0x84, 0x75, 0x4F, 0xAE, 0x76, 0x86, 0xEF, 0x27, 0xFE, 0xDC, 0x86, 0xF7, 0xAB,
        0x5F, 0x33, 0x05, 0x25, 0xB9, 0xAF, 0x4F, 0x8B, 0x25, 0xC9, 0x10, 0xAE, 0x90, 0x5C, 0x19, 0x69,
        0xA6, 0x8C, 0xCE, 0x0B, 0xDD, 0x11, 0x45, 0x85, 0x05, 0x87, 0xE4, 0xA1, 0x3C, 0xD0, 0xDF, 0xB5,
        0x56, 0xB0, 0x44, 0xF4, 0x05, 0x04, 0xF3, 0x35, 0x0E, 0x1E, 0x4A, 0x5C, 0x13, 0x00, 0x00, 0x00,
        0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]
}
