import HTTPTypes

/// A protocol that defines the interface for writing multipart data.
public protocol MultipartWriter<OutboundBody>: Sendable {
    /// The type of the body element that the writer will produce.
    associatedtype OutboundBody: MultipartPartBodyElement

    /// Boundary string used to separate parts in the multipart data.
    var boundary: String { get }

    /// Writes the given bytes to the multipart data.
    mutating func write(bytes: some Collection<UInt8> & Sendable) async throws

    /// Writes the final boundary to the multipart data.
    mutating func finish() async throws
}

extension MultipartWriter {
    private var boundaryPrefix: OutboundBody {
        var prefix = OutboundBody()
        prefix.append(contentsOf: ArraySlice.twoHyphens)
        prefix.append(contentsOf: boundary.utf8)
        return prefix
    }

    private var boundarySuffix: OutboundBody {
        var suffix = OutboundBody()
        suffix.append(contentsOf: ArraySlice.twoHyphens)
        return suffix
    }

    public mutating func writeBoundary(end: Bool = false) async throws {
        var boundaryBytes = Self.OutboundBody()
        boundaryBytes.append(.hyphen)
        boundaryBytes.append(.hyphen)
        boundaryBytes.append(contentsOf: boundary.utf8)
        if end {
            boundaryBytes.append(contentsOf: ArraySlice.twoHyphens)
        }
        boundaryBytes.append(contentsOf: ArraySlice<UInt8>.crlf)
        try await write(bytes: boundaryBytes)
    }

    public mutating func writeHeaders(_ httpFields: HTTPFields) async throws {
        guard !httpFields.isEmpty else {
            try await write(bytes: ArraySlice.crlf)
            return
        }

        var bytes = OutboundBody()
        bytes.reserveCapacity(httpFields.count * 64)
        for field in httpFields {
            bytes.append(contentsOf: field.name.rawName.utf8)
            bytes.append(.colon)
            bytes.append(.space)
            bytes.append(contentsOf: field.value.utf8)
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
        serializedPart.reserveCapacity(part.headerFields.count * 64 + part.body.count + boundary.utf8.count + 10)
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
