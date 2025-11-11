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
    public func encode(_ encodable: some Encodable, boundary: String, name: String) throws -> String {
        let parts: [MultipartPart<[UInt8]>] = try self.parts(from: encodable, rootName: name)
        var writer = MemoryMultipartWriter<[UInt8]>(boundary: boundary)
        for part in parts {
            writer._writePart(part)
        }
        writer._finish()
        let serialized = writer.getResult()
        return String(decoding: serialized, as: UTF8.self)
    }

    public func encode(_ encodable: some FormDataNamedEncodable, boundary: String) throws -> String {
        let parts: [MultipartPart<[UInt8]>] = try self.parts(from: encodable)
        var writer = MemoryMultipartWriter<[UInt8]>(boundary: boundary)
        for part in parts {
            writer._writePart(part)
        }
        writer._finish()
        let serialized = writer.getResult()
        return String(decoding: serialized, as: UTF8.self)
    }

    /// Encodes a `FormDataNamedEncodable` item into some ``MultipartPartBodyElement`` using the supplied boundary.
    ///
    /// ```swift
    /// let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
    /// var buffer = ByteBuffer()
    /// let data = try FormDataEncoder().encode(a, boundary: "123", into: &buffer)
    /// ```
    ///
    /// - parameters:
    ///     - encodable: Generic `FormDataNamedEncodable` item.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    ///     - to: Buffer to write to.
    /// - throws: Any errors encoding the model with `Codable` or serializing the data.
    public func encode<Body: MultipartPartBodyElement>(
        _ encodable: some FormDataNamedEncodable,
        boundary: String,
        to: Body.Type = Body.self
    ) throws -> Body {
        let parts: [MultipartPart<Body>] = try self.parts(from: encodable)
        var writer = MemoryMultipartWriter<Body>(boundary: boundary)
        for part in parts {
            writer._writePart(part)
        }
        writer._finish()
        return writer.getResult()
    }

    /// Encodes an `Encodable` item into some ``MultipartPartBodyElement`` using the supplied boundary.
    ///
    /// This is a separate overload for encoding types which are not conforming to ``FormDataNamedEncodable``.
    /// This overload requires passing in the name of the multipart part manually, as RFC 7578 requires it.
    /// For more info, see https://datatracker.ietf.org/doc/html/rfc7578#section-4.2.
    ///
    /// ```swift
    /// let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
    /// var buffer = ByteBuffer()
    /// let data = try FormDataEncoder().encode(a, boundary: "123", into: &buffer)
    /// ```
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` item.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    ///     - name: The name the part will have, which will be rendered in the Content Disposition header.
    ///     - to: Buffer to write to.
    /// - throws: Any errors encoding the model with `Codable` or serializing the data.
    public func encode<Body: MultipartPartBodyElement>(
        _ encodable: some FormDataNamedEncodable,
        boundary: String,
        name: String,
        to: Body.Type = Body.self
    ) throws -> Body {
        let parts: [MultipartPart<Body>] = try self.parts(from: encodable)
        var writer = MemoryMultipartWriter<Body>(boundary: boundary)
        for part in parts {
            writer._writePart(part)
        }
        writer._finish()
        return writer.getResult()
    }

    private func parts<Body: MultipartPartBodyElement>(
        from encodable: some Encodable, rootName: String? = nil
    ) throws -> [MultipartPart<Body>] {
        let encoder = Encoder<Body>(codingPath: [], userInfo: userInfo)
        try encodable.encode(to: encoder)
        return encoder.storage.data?.namedParts(path: rootName) ?? []
    }
}
