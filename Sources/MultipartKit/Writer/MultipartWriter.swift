import HTTPTypes

/// A protocol that defines the interface for writing multipart data.
///
/// Writers conforming to this protocol can serialize multipart data by writing boundaries,
/// headers, and body chunks in the proper multipart format. The protocol supports both
/// streaming and buffered writing approaches.
///
/// ### Implementing a Custom Writer
///
/// Here's an example of implementing a custom writer that accumulates data in memory:
///
/// ```swift
/// struct MemoryMultipartWriter: MultipartWriter {
///     typealias OutboundBody = [UInt8]
///
///     let boundary: String
///     private var buffer: [UInt8] = []
///
///     init(boundary: String) {
///         self.boundary = boundary
///     }
///
///     mutating func write(bytes: some Collection<UInt8> & Sendable) async throws {
///         buffer.append(contentsOf: bytes)
///     }
///
///     mutating func finish() async throws {
///         try await writeBoundary(end: true)
///     }
///
///     var data: [UInt8] {
///         buffer
///     }
/// }
///
/// // Usage example:
/// var writer = MemoryMultipartWriter(boundary: "boundary123")
/// try await writer.writeBoundary()
/// try await writer.writeHeaders([.contentType: "text/plain"])
/// try await writer.writeBodyChunk("Hello, world!".utf8)
/// try await writer.finish()
/// let result = writer.data
/// ```
public protocol MultipartWriter<OutboundBody>: Sendable {
    /// The type of the body element that the writer will produce.
    associatedtype OutboundBody: MultipartPartBodyElement

    /// Boundary string used to separate parts in the multipart data.
    var boundary: String { get }

    /// Writes the given bytes to the multipart data.
    ///
    /// - Parameter bytes: The bytes to write to the output.
    /// - Throws: Any error that occurs during writing.
    mutating func write(bytes: some Collection<UInt8> & Sendable) async throws

    /// Writes the final boundary to the multipart data.
    ///
    /// This method should be called when all parts have been written to properly
    /// terminate the multipart message.
    ///
    /// - Throws: Any error that occurs during writing.
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

    /// Writes a multipart boundary with optional termination.
    ///
    /// - Parameter end: Whether this is the final boundary that terminates the multipart message.
    /// - Throws: Any error that occurs during writing.
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

    /// Writes HTTP header fields for a multipart part.
    ///
    /// - Parameter httpFields: The header fields to write.
    /// - Throws: Any error that occurs during writing.
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

    /// Writes a single body chunk.
    ///
    /// - Parameter chunk: The body chunk to write.
    /// - Throws: Any error that occurs during writing.
    public mutating func writeBodyChunk(_ chunk: some MultipartPartBodyElement) async throws {
        try await write(bytes: chunk)
    }

    /// Writes multiple body chunks followed by a CRLF sequence.
    ///
    /// - Parameter chunks: A sequence of body chunks to write.
    /// - Throws: Any error that occurs during writing.
    public mutating func writeBodyChunks(_ chunks: some Sequence<some MultipartPartBodyElement>) async throws {
        for chunk in chunks {
            try await write(bytes: chunk)
        }
        try await write(bytes: ArraySlice.crlf)
    }

    /// Writes body chunks from an async sequence followed by a CRLF sequence.
    ///
    /// - Parameter chunks: An async sequence of body chunks to write.
    /// - Throws: Any error that occurs during writing.
    public mutating func writeBodyChunks<Chunks: AsyncSequence>(_ chunks: Chunks) async throws
    where Chunks.Element: MultipartPartBodyElement {
        for try await chunk in chunks {
            try await write(bytes: chunk)
        }
        try await write(bytes: ArraySlice.crlf)
    }

    /// Writes a complete multipart part including boundary, headers, and body.
    ///
    /// - Parameter part: The multipart part to write.
    /// - Throws: Any error that occurs during writing.
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

    /// Writes the final boundary to the multipart data.
    ///
    /// This method should be called when all parts have been written to properly
    /// terminate the multipart message.
    ///
    /// - Throws: Any error that occurs during writing.
    public mutating func finish() async throws {
        try await writeBoundary(end: true)
    }
}
