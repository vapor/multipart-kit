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
    ///     let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
    ///     let data = try FormDataEncoder().encode(a, boundary: "123")
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` item.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    /// - throws: Any errors encoding the model with `Codable` or serializing the data.
    /// - returns: `multipart/form-data`-encoded `String`.
    public func encode<E: Encodable>(_ encodable: E, boundary: String) throws -> String {
        let parts: [MultipartPart<[UInt8]>] = try self.parts(from: encodable)
        return try MultipartSerializer(boundary: boundary).serialize(parts: parts)
    }

    /// Encodes an `Encodable` item into some ``MultipartPartBodyElement`` using the supplied boundary.
    ///
    ///     let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
    ///     var buffer = ByteBuffer()
    ///     let data = try FormDataEncoder().encode(a, boundary: "123", into: &buffer)
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` item.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    ///     - buffer: Buffer to write to.
    /// - throws: Any errors encoding the model with `Codable` or serializing the data.
    public func encode<E: Encodable, Body: MultipartPartBodyElement>(
        _ encodable: E,
        boundary: String,
        to: Body.Type = Body.self
    ) throws -> Body where Body: RangeReplaceableCollection {
        let parts: [MultipartPart<Body>] = try self.parts(from: encodable)
        return try MultipartSerializer(boundary: boundary).serialize(parts: parts)
    }

    private func parts<E: Encodable, Body: MultipartPartBodyElement>(from encodable: E) throws -> [MultipartPart<Body>]
    where Body: RangeReplaceableCollection {
        let encoder = Encoder<Body>(codingPath: [], userInfo: userInfo)
        try encodable.encode(to: encoder)
        return encoder.storage.data?.namedParts() ?? []
    }
}
