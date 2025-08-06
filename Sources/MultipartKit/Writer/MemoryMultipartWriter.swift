import HTTPTypes

/// A synchronous ``MultipartWriter`` that buffers the output in memory.
///
/// This writer accumulates all multipart data in an internal buffer, making it suitable
/// for scenarios where you need to generate the complete multipart message before sending.
/// The buffer can be retrieved using ``getResult()`` after writing all parts.
///
/// ```swift
/// var writer = MemoryMultipartWriter<[UInt8]>(boundary: "boundary123")
/// try await writer.writePart(MultipartPart(
///     headerFields: [.contentType: "text/plain"],
///     body: Array("Hello, world!".utf8)
/// ))
/// try await writer.finish()
/// let result = writer.getResult()
/// ```
public struct MemoryMultipartWriter<OutboundBody: MultipartPartBodyElement>: MultipartWriter {
    public let boundary: String

    @usableFromInline
    var buffer: OutboundBody

    /// Creates a new buffered multipart writer with the specified boundary.
    ///
    /// - Parameter boundary: The boundary string to use for separating multipart parts.
    @inlinable
    public init(boundary: String) {
        self.boundary = boundary
        self.buffer = OutboundBody()
    }

    @inlinable
    public mutating func write(bytes: some Collection<UInt8> & Sendable) async throws {
        buffer.append(contentsOf: bytes)
    }

    /// Retrieves the buffered result and clears the internal buffer.
    ///
    /// - Returns: The complete multipart message as the specified body type.
    @inlinable
    public mutating func getResult() -> OutboundBody {
        defer { buffer.removeAll() }
        return buffer
    }

    @inlinable
    public mutating func finish() async throws {
        self._finish()
    }

    @inlinable
    public mutating func writePart(_ part: MultipartPart<some MultipartPartBodyElement>) async throws {
        // Since we have the internal, somewhat more efficient methods, might as well use those.
        self._writePart(part)
    }

    // Internal sync version of some of the methods, used in ``FormDataEncoder``.

    @inlinable
    mutating func _writePart(_ part: MultipartPart<some MultipartPartBodyElement>) {
        buffer.reserveCapacity(part.headerFields.count * 64 + part.body.count + boundary.utf8.count + 10)
        buffer.append(contentsOf: ArraySlice.twoHyphens)
        buffer.append(contentsOf: boundary.utf8)
        buffer.append(contentsOf: ArraySlice.crlf)
        for field in part.headerFields {
            buffer.append(contentsOf: field.name.rawName.utf8)
            buffer.append(contentsOf: ArraySlice.colonSpace)
            buffer.append(contentsOf: field.value.utf8)
            buffer.append(contentsOf: ArraySlice.crlf)
        }
        buffer.append(contentsOf: ArraySlice.crlf)
        buffer.append(contentsOf: part.body)
        buffer.append(contentsOf: ArraySlice.crlf)
    }

    @inlinable
    mutating func _finish() {
        buffer.reserveCapacity(boundary.utf8.count + 10)
        buffer.append(contentsOf: ArraySlice.twoHyphens)
        buffer.append(contentsOf: boundary.utf8)
        buffer.append(contentsOf: ArraySlice.twoHyphens)
        buffer.append(contentsOf: ArraySlice.crlf)
    }
}
