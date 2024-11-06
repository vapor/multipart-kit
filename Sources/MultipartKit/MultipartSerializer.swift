/// Serializes `MultipartForm`s to `Data`.
///
/// See `MultipartParser` for more information about the multipart encoding.
public struct MultipartSerializer: Sendable {
    let boundary: String

    /// Creates a new `MultipartSerializer`.
    init(boundary: String) {
        self.boundary = boundary
    }

    /// Serializes the `MultipartForm` to data.
    ///
    ///     let data = try MultipartSerializer().serialize(parts: [part], boundary: "123")
    ///     print(data) // multipart-encoded
    ///
    /// - parameters:
    ///     - parts: One or more `MultipartPart`s to serialize into `Data`.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    /// - throws: Any errors that may occur during serialization.
    /// - returns: `multipart`-encoded `Data`.
    public func serialize(parts: [MultipartPart<some Collection<UInt8>>]) throws -> String {
        var buffer = [UInt8]()
        try self.serialize(parts: parts, into: &buffer)
        return String(decoding: buffer, as: UTF8.self)
    }

    /// Serializes the `MultipartForm` into a `ByteBuffer`.
    ///
    ///     var buffer = ByteBuffer()
    ///     try MultipartSerializer().serialize(parts: [part], boundary: "123", into: &buffer)
    ///     print(String(buffer: buffer)) // multipart-encoded
    ///
    /// - parameters:
    ///     - parts: One or more `MultipartPart`s to serialize into `Data`.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    ///     - buffer: Buffer to write to.
    /// - throws: Any errors that may occur during serialization.
    public func serialize(parts: [MultipartPart<some Collection<UInt8>>], into buffer: inout [UInt8]) throws {
        for part in parts {
            buffer.append(contentsOf: Array("--\(boundary)\r\n".utf8))
            for field in part.headerFields {
                buffer.append(contentsOf: Array("\(field.description)\r\n".utf8))
            }
            buffer.append(contentsOf: Array("\r\n".utf8))
            buffer.append(contentsOf: part.body)
            buffer.append(contentsOf: Array("\r\n".utf8))
        }
        buffer.append(contentsOf: Array("--\(boundary)--\r\n".utf8))
    }
}
