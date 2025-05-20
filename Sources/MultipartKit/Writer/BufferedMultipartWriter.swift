import HTTPTypes

/// A synchronous ``MultipartWriter`` that buffers the output in memory.
public struct BufferedMultipartWriter<OutboundBody: MultipartPartBodyElement>: MultipartWriter {
    public let boundary: String
    private var buffer: OutboundBody

    public init(boundary: String) {
        self.boundary = boundary
        self.buffer = OutboundBody()
    }

    public mutating func write(bytes: some MultipartPartBodyElement) {
        buffer.append(contentsOf: bytes)
    }

    public mutating func getResult() -> OutboundBody {
        let resultBuffer = buffer
        buffer = OutboundBody()
        return resultBuffer
    }

    public mutating func finish() {
        writeBoundary(end: true)
    }

    public mutating func writeBoundary(end: Bool = false) {
        var boundaryBytes = OutboundBody()
        boundaryBytes.append(.hyphen)
        boundaryBytes.append(.hyphen)
        boundaryBytes.append(contentsOf: boundary.utf8)
        if end {
            boundaryBytes.append(.hyphen)
            boundaryBytes.append(.hyphen)
        }
        boundaryBytes.append(contentsOf: ArraySlice<UInt8>.crlf)
        write(bytes: boundaryBytes)
    }

    public mutating func writeHeaders(_ httpFields: HTTPFields) {
        var bytes = OutboundBody()
        for field in httpFields {
            bytes.append(contentsOf: field.description.utf8)
            bytes.append(contentsOf: ArraySlice.crlf)
        }
        bytes.append(contentsOf: ArraySlice.crlf)
        write(bytes: bytes)
    }

    public mutating func writeBodyChunk(_ chunk: some MultipartPartBodyElement) {
        write(bytes: chunk)
    }

    public mutating func writeBodyChunks(_ chunks: some Sequence<some MultipartPartBodyElement>) {
        for chunk in chunks {
            write(bytes: chunk)
        }
        write(bytes: ArraySlice.crlf)
    }

    mutating func writePart(_ part: MultipartPart<some MultipartPartBodyElement>) {
        var serializedPart = OutboundBody()
        serializedPart.append(.hyphen)
        serializedPart.append(.hyphen)
        serializedPart.append(contentsOf: boundary.utf8)
        serializedPart.append(contentsOf: ArraySlice<UInt8>.crlf)
        for field in part.headerFields {
            serializedPart.append(contentsOf: field.description.utf8)
            serializedPart.append(contentsOf: ArraySlice.crlf)
        }
        serializedPart.append(contentsOf: ArraySlice.crlf)
        serializedPart.append(contentsOf: part.body)
        serializedPart.append(contentsOf: ArraySlice.crlf)
        write(bytes: serializedPart)
    }
}
