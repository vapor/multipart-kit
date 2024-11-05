/// Serializes `MultipartForm`s to `Data`.
///
/// See `MultipartParser` for more information about the multipart encoding.
public enum MultipartSerializer: Sendable {
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
    public static func serialize(parts: [MultipartPart<some Collection<UInt8>>], boundary: String) throws -> String {
        var buffer = [UInt8]()
        try self.serialize(parts: parts, boundary: boundary, into: &buffer)
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
    public static func serialize(parts: [MultipartPart<some Collection<UInt8>>], boundary: String, into buffer: inout [UInt8]) throws {
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
