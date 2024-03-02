import Foundation
import NIOCore
import NIOFoundationCompat

/// Serializes `MultipartForm`s to `Data`.
///
/// See `MultipartParser` for more information about the multipart encoding.
public final class MultipartSerializer: Sendable {

    /// Creates a new `MultipartSerializer`.
    public init() { }

    /// Serializes the `MultipartForm` to data.
    ///
    ///     let data = try MultipartSerializer().serialize(parts: [part], boundary: "123")
    ///     print(data) // multipart-encoded
    ///
    /// - Parameters:
    ///     - parts: One or more `MultipartPart`s to serialize into `String`.
    ///     - boundary: The multipart boundary to use for encoding. This string must not appear in the encoded data.
    /// - Throws: Any errors that may occur during serialization.
    /// - Returns: A `multipart`-encoded `Data`.
    public func serialize(parts: [MultipartPart], boundary: String) throws -> String {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        try self.serialize(parts: parts, boundary: boundary, into: &buffer)
        return String(buffer: buffer)
    }
    
    /// Serializes the `MultipartForm` to data.
    ///
    ///     let data = try MultipartSerializer().serializeToData(parts: [part], boundary: "123")
    ///     print(data) // multipart-encoded
    ///
    /// - Parameters:
    ///     - parts: One or more `MultipartPart`s to serialize into `Data`.
    ///     - boundary: The multipart boundary to use for encoding. This string must not appear in the encoded data.
    /// - Throws: Any errors that may occur during serialization.
    /// - Returns: A `multipart`-encoded `Data`.
    public func serializeToData(parts: [MultipartPart], boundary: String) throws -> Data {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        try self.serialize(parts: parts, boundary: boundary, into: &buffer)
        return Data(buffer: buffer, byteTransferStrategy: .automatic)
    }

    /// Serializes the `MultipartForm` into a `ByteBuffer`.
    ///
    ///     var buffer = ByteBuffer()
    ///     try MultipartSerializer().serialize(parts: [part], boundary: "123", into: &buffer)
    ///     print(String(buffer: buffer)) // multipart-encoded
    ///
    /// - Parameters:
    ///     - parts: One or more `MultipartPart`s to serialize into `Data`.
    ///     - boundary: The multipart boundary to use for encoding. This string must not appear in the encoded data.
    ///     - buffer: Buffer to write to.
    /// - Throws: Any errors that may occur during serialization.
    public func serialize(parts: [MultipartPart], boundary: String, into buffer: inout ByteBuffer) throws {
        for part in parts {
            buffer.writeString("--")
            buffer.writeString(boundary)
            buffer.writeString("\r\n")
            for (key, val) in part.headers {
                buffer.writeString(key)
                buffer.writeString(": ")
                buffer.writeString(val)
                buffer.writeString("\r\n")
            }
            buffer.writeString("\r\n")
            var body = part.body
            buffer.writeBuffer(&body)
            buffer.writeString("\r\n")
        }
        buffer.writeString("--")
        buffer.writeString(boundary)
        buffer.writeString("--\r\n")
    }
}
