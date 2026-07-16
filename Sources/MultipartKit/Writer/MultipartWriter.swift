public import HTTPTypes

/// A protocol that defines the interface for writing multipart data.
///
/// Writers conforming to this protocol can serialize multipart data by writing boundaries,
/// headers, and body chunks in the proper multipart format. The protocol supports both
/// streaming and buffered writing approaches.
///
/// ### Implementing a Custom Writer
///
/// Only ``write(bytes:)`` has to be implemented. Boundaries, header fields, and whole parts are
/// all written in terms of it by the default implementations, so a writer that sends a message
/// somewhere is as small as this:
///
/// ```swift
/// struct StdoutMultipartWriter: MultipartWriter {
///     typealias OutboundBody = [UInt8]
///
///     let boundary: String
///
///     func write(bytes: some Collection<UInt8> & Sendable) async throws {
///         print(String(decoding: bytes, as: UTF8.self), terminator: "")
///     }
/// }
///
/// // Usage example:
/// var writer = StdoutMultipartWriter(boundary: "boundary123")
/// try await writer.writeBoundary()
/// try await writer.writeHeaders([.contentType: "text/plain"])
/// try await writer.writeBodyChunk(Array("Hello, world!".utf8))
/// try await writer.finish()
/// ```
public protocol MultipartWriter<OutboundBody>: Sendable {
    /// The type of the body element that the writer will produce.
    associatedtype OutboundBody: MultipartPartBodyElement
    /// The error the conforming writer will throw. Defaults to `Never`,
    /// i.e. the writer doesn't throw.
    associatedtype Failure: Error = Never

    /// Boundary string used to separate parts in the multipart data.
    var boundary: String { get }

    /// Writes the given bytes to the multipart data.
    ///
    /// - Parameter bytes: The bytes to write to the output.
    mutating func write(bytes: some Collection<UInt8> & Sendable) async throws(Failure)

    /// Writes the final boundary to the multipart data.
    ///
    /// This method should be called when all parts have been written to properly
    /// terminate the multipart message.
    mutating func finish() async throws(Failure)

    /// Writes a multipart boundary with optional termination.
    ///
    /// - Parameter end: Whether this is the final boundary that terminates the multipart message.
    /// - Note: Override this method only for performance reasons. Most implementations should rely on the default
    ///   implementation unless specific performance optimizations are needed.
    mutating func writeBoundary(end: Bool) async throws(Failure)

    /// Writes HTTP header fields for a multipart part.
    ///
    /// - Parameter httpFields: The header fields to write.
    /// - Note: Override this method only for performance reasons. Most implementations should rely on the default
    ///   implementation unless specific performance optimizations are needed.
    mutating func writeHeaders(_ httpFields: HTTPFields) async throws(Failure)

    /// Writes a complete multipart part including boundary, headers, and body.
    ///
    /// - Parameter part: The multipart part to write.
    /// - Note: Override this method only for performance reasons. Most implementations should rely on the default
    ///   implementation unless specific performance optimizations are needed.
    mutating func writePart(_ part: MultipartPart<some MultipartPartBodyElement>) async throws(Failure)
}

extension MultipartWriter {
    /// Writes a multipart boundary with optional termination.
    ///
    /// - Parameter end: Whether this is the final boundary that terminates the multipart message.
    /// - Throws: The writer's `Failure`.
    @inlinable
    public mutating func writeBoundary(end: Bool = false) async throws(Failure) {
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
    /// - Throws: The writer's `Failure`.
    @inlinable
    public mutating func writeHeaders(_ httpFields: HTTPFields) async throws(Failure) {
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
    /// - Throws: The writer's `Failure`.
    @inlinable
    public mutating func writeBodyChunk(_ chunk: some MultipartPartBodyElement) async throws(Failure) {
        try await write(bytes: chunk)
    }

    /// Writes multiple body chunks followed by a CRLF sequence.
    ///
    /// - Parameter chunks: A sequence of body chunks to write.
    /// - Throws: The writer's `Failure`.
    @inlinable
    public mutating func writeBodyChunks(_ chunks: some Sequence<some MultipartPartBodyElement>) async throws(Failure) {
        for chunk in chunks {
            try await write(bytes: chunk)
        }
        try await write(bytes: ArraySlice.crlf)
    }

    /// Writes body chunks from an async sequence followed by a CRLF sequence.
    ///
    /// - Parameter chunks: An async sequence of body chunks to write.
    /// - Throws: The writer's `Failure` or any error from the backing sequence.
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
    /// - Throws: The writer's `Failure`.
    @inlinable
    public mutating func writePart(_ part: MultipartPart<some MultipartPartBodyElement>) async throws(Failure) {
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
    /// - Throws: The writer's `Failure`.
    @inlinable
    public mutating func finish() async throws(Failure) {
        try await writeBoundary(end: true)
    }
}

/// Creates a properly formatted boundary to be used in a custom
/// ``MultipartWriter/writeBoundary(end:)`` implementation.
///
/// - Parameters:
///   - boundary: The boundary to be formatted.
///   - end: Whether this is the end boundary of the message.
///   - as: The body type to produce the boundary as.
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
