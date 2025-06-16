import HTTPTypes

/// A ``MultipartWriter`` that buffers data up to a specified capacity before forwarding to an underlying writer.
///
/// This writer acts as a buffer between your application and another writer implementation,
/// helping to optimize memory usage and improve performance when dealing with large multipart messages.
/// It accumulates data until a threshold is reached, then forwards the buffered content to the underlying
/// writer and clears its internal buffer.
///
/// ```swift
/// // Example: Create a buffered writer with 8KB capacity that writes to a socket
/// var writer = BufferedMultipartWriter(
///     boundary: "boundary123",
///     bufferCapacity: 8192,
///     underlyingWriter: SocketMultipartWriter(socket: mySocket)
/// )
///
/// // Use the writer as normal - buffering happens automatically
/// try await writer.writePart(myPart)
/// try await writer.finish()
/// ```
public struct BufferedMultipartWriter<OutboundBody: MultipartPartBodyElement>: MultipartWriter {
    /// The boundary string used to separate multipart parts.
    public let boundary: String

    /// The underlying writer that will receive the buffered data.
    @usableFromInline
    var underlyingWriter: any MultipartWriter<OutboundBody>

    /// Internal buffer that accumulates data before forwarding to the underlying writer.
    @usableFromInline
    var buffer: OutboundBody

    /// Current count of bytes in the buffer.
    @usableFromInline
    var currentBufferCount: Int

    /// Maximum capacity of the buffer before flushing to the underlying writer.
    @usableFromInline
    let bufferCapacity: Int

    /// Creates a new buffered multipart writer.
    ///
    /// - Parameters:
    ///   - boundary: The boundary string to use for separating multipart parts.
    ///   - bufferCapacity: Maximum number of bytes to buffer before writing to the underlying writer.
    ///   - underlyingWriter: The writer that will receive the buffered data when capacity is reached.
    @inlinable
    public init(boundary: String, bufferCapacity: Int, underlyingWriter: some MultipartWriter<OutboundBody>) {
        self.boundary = boundary
        self.buffer = OutboundBody()
        self.bufferCapacity = bufferCapacity
        self.buffer.reserveCapacity(bufferCapacity)
        self.currentBufferCount = 0
        self.underlyingWriter = underlyingWriter
    }

    /// Writes bytes to the buffer, flushing to the underlying writer if capacity is reached.
    ///
    /// This method accumulates the provided bytes in the internal buffer. If the buffer's
    /// capacity is reached, the entire buffer is forwarded to the underlying writer and then cleared.
    ///
    /// - Parameter bytes: The bytes to write to the buffer.
    @inlinable
    public mutating func write(bytes: some Collection<UInt8> & Sendable) async throws {
        if currentBufferCount + bytes.count >= bufferCapacity {
            try await underlyingWriter.write(bytes: self.buffer)
            buffer.removeAll(keepingCapacity: true)
            currentBufferCount = 0
        } else {
            buffer.append(contentsOf: bytes)
            currentBufferCount += bytes.count
        }
    }

    /// If the buffer has not been emptied by the last write,
    /// flushes the final part of the message to the underlying writer.
    public mutating func finish() async throws {
        if currentBufferCount != 0 {
            try await underlyingWriter.write(bytes: self.buffer)
            buffer.removeAll(keepingCapacity: true)
            currentBufferCount = 0
        }
    }
}
