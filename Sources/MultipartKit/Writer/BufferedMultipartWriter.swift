import HTTPTypes

/// A synchronous ``MultipartWriter`` that buffers the output in memory.
public struct BufferedMultipartWriter<OutboundBody: MultipartPartBodyElement>: MultipartWriter {
    public let boundary: String
    private var buffer: OutboundBody

    public init(boundary: String) {
        self.boundary = boundary
        self.buffer = OutboundBody()
    }

    public mutating func write(bytes: some Collection<UInt8> & Sendable) async throws {
        buffer.append(contentsOf: bytes)
    }

    public mutating func getResult() -> OutboundBody {
        defer { buffer.removeAll() }
        return buffer
    }

    public mutating func finish() async throws {
        try await writeBoundary(end: true)
    }

    public mutating func writeBoundary(end: Bool = false) async throws {
        buffer.reserveCapacity(boundary.utf8.count + 10)
        buffer.append(.hyphen)
        buffer.append(.hyphen)
        buffer.append(contentsOf: boundary.utf8)
        if end {
            buffer.append(.hyphen)
            buffer.append(.hyphen)
        }
        buffer.append(contentsOf: ArraySlice.crlf)
    }

    public mutating func writeHeaders(_ httpFields: HTTPFields) async throws {
        buffer.reserveCapacity(httpFields.count * 64)
        for field in httpFields {
            buffer.append(contentsOf: field.name.rawName.utf8)
            buffer.append(.colon)
            buffer.append(.space)
            buffer.append(contentsOf: field.value.utf8)
            buffer.append(contentsOf: ArraySlice.crlf)
        }
        buffer.append(contentsOf: ArraySlice.crlf)
    }

    public mutating func writeBodyChunk(_ chunk: some MultipartPartBodyElement) async throws {
        buffer.append(contentsOf: chunk)
    }

    public mutating func writeBodyChunks(_ chunks: some Sequence<some MultipartPartBodyElement>) async throws {
        buffer.reserveCapacity(chunks.underestimatedCount * 64 + ArraySlice.crlf.count)
        for chunk in chunks {
            buffer.append(contentsOf: chunk)
        }
        buffer.append(contentsOf: ArraySlice.crlf)
    }

    public mutating func writePart(_ part: MultipartPart<some MultipartPartBodyElement>) async throws {
        buffer.reserveCapacity(part.headerFields.count * 64 + part.body.count + boundary.utf8.count + 10)
        buffer.append(.hyphen)
        buffer.append(.hyphen)
        buffer.append(contentsOf: boundary.utf8)
        buffer.append(contentsOf: ArraySlice.crlf)
        for field in part.headerFields {
            buffer.append(contentsOf: field.name.rawName.utf8)
            buffer.append(.colon)
            buffer.append(.space)
            buffer.append(contentsOf: field.value.utf8)
            buffer.append(contentsOf: ArraySlice.crlf)
        }
        buffer.append(contentsOf: ArraySlice.crlf)
        buffer.append(contentsOf: part.body)
        buffer.append(contentsOf: ArraySlice.crlf)
    }

    // Internal sync version of some of the methods, used in ``FormDataEncoder``.

    mutating func writePart(_ part: MultipartPart<some MultipartPartBodyElement>) {
        buffer.reserveCapacity(part.headerFields.count * 64 + part.body.count + boundary.utf8.count + 10)
        buffer.append(.hyphen)
        buffer.append(.hyphen)
        buffer.append(contentsOf: boundary.utf8)
        buffer.append(contentsOf: ArraySlice<UInt8>.crlf)
        for field in part.headerFields {
            buffer.append(contentsOf: field.name.rawName.utf8)
            buffer.append(.colon)
            buffer.append(.space)
            buffer.append(contentsOf: field.value.utf8)
            buffer.append(contentsOf: ArraySlice.crlf)
        }
        buffer.append(contentsOf: ArraySlice.crlf)
        buffer.append(contentsOf: part.body)
        buffer.append(contentsOf: ArraySlice.crlf)
    }

    mutating func finish() {
        buffer.reserveCapacity(boundary.utf8.count + 10)
        buffer.append(.hyphen)
        buffer.append(.hyphen)
        buffer.append(contentsOf: boundary.utf8)
        buffer.append(.hyphen)
        buffer.append(.hyphen)
        buffer.append(contentsOf: ArraySlice.crlf)
    }
}
