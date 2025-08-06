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
    mutating func write(bytes: some Collection<UInt8> & Sendable) async throws

    /// Writes the final boundary to the multipart data.
    ///
    /// This method should be called when all parts have been written to properly
    /// terminate the multipart message.
    mutating func finish() async throws

    /// Writes a multipart boundary with optional termination.
    ///
    /// - Parameter end: Whether this is the final boundary that terminates the multipart message.
    /// - Note: Override this method only for performance reasons. Most implementations should rely on the default
    ///   implementation unless specific performance optimizations are needed.
    mutating func writeBoundary(end: Bool) async throws

    /// Writes HTTP header fields for a multipart part.
    ///
    /// - Parameter httpFields: The header fields to write.
    /// - Note: Override this method only for performance reasons. Most implementations should rely on the default
    ///   implementation unless specific performance optimizations are needed.
    mutating func writeHeaders(_ httpFields: HTTPFields) async throws

    /// Writes a complete multipart part including boundary, headers, and body.
    ///
    /// - Parameter part: The multipart part to write.
    /// - Note: Override this method only for performance reasons. Most implementations should rely on the default
    ///   implementation unless specific performance optimizations are needed.
    mutating func writePart(_ part: MultipartPart<some MultipartPartBodyElement>) async throws
}

extension MultipartWriter {
    /// Writes a multipart boundary with optional termination.
    ///
    /// - Parameter end: Whether this is the final boundary that terminates the multipart message.
    /// - Throws: Any error that occurs during writing.
    @inlinable
    public mutating func writeBoundary(end: Bool = false) async throws {
        try await write(bytes: ArraySlice.twoHyphens)
        try await write(bytes: boundary.utf8)
        if end {
            try await write(bytes: ArraySlice.twoHyphens)
        }
        try await write(bytes: ArraySlice.crlf)
    }

    /// Writes HTTP header fields for a multipart part.
    ///
    /// - Parameter httpFields: The header fields to write.
    /// - Throws: Any error that occurs during writing.
    @inlinable
    public mutating func writeHeaders(_ httpFields: HTTPFields) async throws {
        for field in httpFields {
            try await write(bytes: field.name.rawName.utf8)
            try await write(bytes: ArraySlice.colonSpace)
            try await write(bytes: field.value.utf8)
            try await write(bytes: ArraySlice.crlf)
        }
        try await write(bytes: ArraySlice.crlf)
    }

    /// Writes a single body chunk.
    ///
    /// - Parameter chunk: The body chunk to write.
    /// - Throws: Any error that occurs during writing.
    @inlinable
    public mutating func writeBodyChunk(_ chunk: some MultipartPartBodyElement) async throws {
        try await write(bytes: chunk)
    }

    /// Writes multiple body chunks followed by a CRLF sequence.
    ///
    /// - Parameter chunks: A sequence of body chunks to write.
    /// - Throws: Any error that occurs during writing.
    @inlinable
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
    @inlinable
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
    @inlinable
    public mutating func writePart(_ part: MultipartPart<some MultipartPartBodyElement>) async throws {
        try await writeBoundary()
        try await writeHeaders(part.headerFields)
        try await writeBodyChunk(part.body)
        try await write(bytes: ArraySlice.crlf)
    }

    /// Writes the final boundary to the multipart data.
    ///
    /// This method should be called when all parts have been written to properly
    /// terminate the multipart message.
    ///
    /// - Throws: Any error that occurs during writing.
    @inlinable
    public mutating func finish() async throws {
        try await writeBoundary(end: true)
    }
}

/// Creates a properly formatted boundary to be used in a custom ``MultipartSerializer.writeBoundary`` method.
///
/// - Parameters:
///   - boundary: The boundary to be formatted.
///   - end: Whether this is the end boundary of the message.
/// - Returns: A formatted boundary.
public func makeBoundaryBytes<OutboundBody: MultipartPartBodyElement>(
    _ boundary: String,
    end: Bool = false,
    as: OutboundBody.Type = OutboundBody.self
) -> OutboundBody {
    var bytes = OutboundBody()
    bytes.append(contentsOf: ArraySlice.twoHyphens)
    bytes.append(contentsOf: boundary.utf8)
    if end {
        bytes.append(contentsOf: ArraySlice.twoHyphens)
    }
    bytes.append(contentsOf: ArraySlice.crlf)
    return bytes
}
