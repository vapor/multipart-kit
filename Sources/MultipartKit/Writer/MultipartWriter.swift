import HTTPTypes

/// A protocol that defines the interface for writing multipart data.
public protocol MultipartWriter<OutboundBody>: Sendable {
    /// The type of the body element that the writer will produce.
    associatedtype OutboundBody: MultipartPartBodyElement

    /// Boundary string used to separate parts in the multipart data.
    var boundary: String { get }

    /// Writes the given bytes to the multipart data.
    mutating func write(bytes: some MultipartPartBodyElement) async throws

    /// Writes the final boundary to the multipart data.
    mutating func finish() async throws
}

extension MultipartWriter {
    public mutating func writeBoundary(end: Bool = false) async throws {
        var boundaryBytes = Self.OutboundBody()
        boundaryBytes.append(.hyphen)
        boundaryBytes.append(.hyphen)
        boundaryBytes.append(contentsOf: boundary.utf8)
        if end {
            boundaryBytes.append(.hyphen)
            boundaryBytes.append(.hyphen)
        }
        boundaryBytes.append(contentsOf: ArraySlice<UInt8>.crlf)
        try await write(bytes: boundaryBytes)
    }

    public mutating func writeHeaders(_ httpFields: HTTPFields) async throws {
        var bytes = OutboundBody()
        for field in httpFields {
            bytes.append(contentsOf: field.description.utf8)
            bytes.append(contentsOf: ArraySlice.crlf)
        }
        bytes.append(contentsOf: ArraySlice.crlf)
        try await write(bytes: bytes)
    }

    public mutating func writeBodyChunk(_ chunk: some MultipartPartBodyElement) async throws {
        try await write(bytes: chunk)
    }

    public mutating func writeBodyChunks(_ chunks: some Sequence<some MultipartPartBodyElement>) async throws {
        for chunk in chunks {
            try await write(bytes: chunk)
        }
        try await write(bytes: ArraySlice.crlf)
    }

    public mutating func writeBodyChunks<Chunks: AsyncSequence>(_ chunks: Chunks) async throws
    where Chunks.Element: MultipartPartBodyElement {
        for try await chunk in chunks {
            try await write(bytes: chunk)
        }
        try await write(bytes: ArraySlice.crlf)
    }

    public mutating func writePart(_ part: MultipartPart<some MultipartPartBodyElement>) async throws {
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
        try await write(bytes: serializedPart)
    }

    public mutating func finish() async throws {
        try await writeBoundary(end: true)
    }
}
