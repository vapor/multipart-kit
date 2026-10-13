/// Encodes `Encodable` items to `multipart/form-data` encoded `Data`.
///
/// See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
///
/// - Seealso: ``MultipartParser`` for more information about the `multipart` encoding.
public struct FormDataEncoder: Sendable {
    /// Any contextual information set by the user for encoding.
    public var userInfo: [CodingUserInfoKey: any Sendable] = [:]

    /// Creates a new `FormDataEncoder`.
    public init() {}

    /// Encodes an `Encodable` item to `String` using the supplied boundary.
    ///
    /// ```swift
    /// let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
    /// let data = try FormDataEncoder().encode(a, boundary: "123")
    /// ```
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` item.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    /// - throws: Any errors encoding the model with `Codable` or serializing the data.
    /// - returns: `multipart/form-data`-encoded `String`.
    public func encode<E: Encodable>(_ encodable: E, boundary: String) throws -> String {
        let serialized: [UInt8] = try self.encode(encodable, boundary: boundary)
        return String(decoding: serialized, as: Unicode.UTF8.self)
    }

    /// Encodes an `Encodable` item into some ``MultipartPartBodyElement`` using the supplied boundary.
    ///
    /// ```swift
    /// let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
    /// let data: [UInt8] = try FormDataEncoder().encode(a, boundary: "123")
    /// ```
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` item.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    ///     - to: Buffer type to write to.
    /// - throws: Any errors encoding the model with `Codable` or serializing the data.
    public func encode<E: Encodable, Body: MultipartPartBodyElement>(
        _ encodable: E,
        boundary: String,
        to: Body.Type = Body.self
    ) throws -> Body {
        var buffer = Body()
        try self.encode(encodable, boundary: boundary, into: &buffer)
        return buffer
    }

    /// Encodes an `Encodable` item into some ``MultipartPartBodyElement`` using the supplied boundary.
    ///
    /// ```swift
    /// let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
    /// var buffer = ByteBufferView()
    /// let data = try FormDataEncoder().encode(a, boundary: "123", into: &buffer)
    /// ```
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` item.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    ///     - buffer: Buffer to write to.
    /// - throws: Any errors encoding the model with `Codable` or serializing the data.
    public func encode<E: Encodable, Body: MultipartPartBodyElement>(
        _ encodable: E,
        boundary: String,
        into buffer: inout Body
    ) throws {
        let encoder = Encoder<Body>(codingPath: [], userInfo: userInfo)
        try encodable.encode(to: encoder)
        let parts: [DeferrableBodyPart<Body>] = encoder.storage.data?.namedParts() ?? []

        var writer = MemoryMultipartWriter<Body>(boundary: boundary, buffer: &buffer)
        for part in parts {
            writer._writePart(part)
        }
        writer._finish()
        buffer = writer.getResult()
    }
}
