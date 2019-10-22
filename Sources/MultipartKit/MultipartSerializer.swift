/// Serializes `MultipartForm`s to `Data`.
///
/// See `MultipartParser` for more information about the multipart encoding.
public final class MultipartSerializer {
    /// Creates a new `MultipartSerializer`.
    public init() { }

    public func serialize(parts: [MultipartPart], boundary: String) throws -> String {
        var buffer: [UInt8] = []
        try self.serialize(parts: parts, boundary: boundary, into: &buffer)
        return String(decoding: buffer, as: UTF8.self)
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
    public func serialize(parts: [MultipartPart], boundary: String, into buffer: inout [UInt8]) throws {
        for part in parts {
            buffer.write(string: "--")
            buffer.write(string: boundary)
            buffer.write(string: "\r\n")
            for (key, val) in part.headers {
                buffer.write(string: key)
                buffer.write(string: ": ")
                buffer.write(string: val)
                buffer.write(string: "\r\n")
            }
            buffer.write(string: "\r\n")
            buffer += part.body
            buffer.write(string: "\r\n")
        }
        buffer.write(string: "--")
        buffer.write(string: boundary)
        buffer.write(string: "--\r\n")
    }
}
