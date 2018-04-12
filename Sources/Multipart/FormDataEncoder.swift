/// Encodes `Encodable` items to `multipart/form-data` encoded `Data`.
///
/// See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
///
/// Seealso `MultipartParser` for more information about the `multipart` encoding.
public final class FormDataEncoder {
    /// Creates a new `FormDataEncoder`.
    public init() { }

    /// Encodes an `Encodable` item to `Data` using the supplied boundary.
    ///
    ///     let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
    ///     let data = try FormDataEncoder().encode(a, boundary: "123")
    ///
    /// - parameters:
    ///     - encodable: Generic `Encodable` item.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    /// - throws: Any errors encoding the model with `Codable` or serializing the data.
    /// - returns: `multipart/form-data`-encoded `Data`.
    public func encode<E>(_ encodable: E, boundary: LosslessDataConvertible) throws -> Data where E: Encodable {
        let multipart = FormDataEncoderContext()
        let encoder = _FormDataEncoder(multipart: multipart, codingPath: [])
        try encodable.encode(to: encoder)
        return try MultipartSerializer().serialize(parts: multipart.parts, boundary: boundary)
    }
}

// MARK: Private

private final class FormDataEncoderContext {
    var parts: [MultipartPart]
    init() {
        self.parts = []
    }
}

private struct _FormDataEncoder: Encoder {
    let codingPath: [CodingKey]
    let multipart: FormDataEncoderContext
    var userInfo: [CodingUserInfoKey: Any] {
        return [:]
    }

    init(multipart: FormDataEncoderContext, codingPath: [CodingKey]) {
        self.multipart = multipart
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return KeyedEncodingContainer(_FormDataKeyedEncoder(self))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return _FormDataUnkeyedEncoder(self)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return _FormDataSingleValueEncoder(self)
    }
}

private struct _FormDataSingleValueEncoder: SingleValueEncodingContainer {
    let encoder: _FormDataEncoder
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }

    init(_ encoder: _FormDataEncoder) {
        self.encoder = encoder
    }

    mutating func encodeNil() throws {
        // do nothing
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        guard let convertible = value as? MultipartPartConvertible else {
            throw MultipartError(identifier: "convertible", reason: "`\(T.self)` is not `MultipartPartConvertible`.")
        }

        let name = codingPath.map { $0.stringValue }.joined(separator: ".")
        var part = try convertible.convertToMultipartPart()
        part.name = name
        encoder.multipart.parts.append(part)
    }
}

private struct _FormDataUnkeyedEncoder: UnkeyedEncodingContainer {
    let encoder: _FormDataEncoder
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }
    var count: Int

    init(_ encoder: _FormDataEncoder) {
        self.encoder = encoder
        self.count = 0
    }

    mutating func encodeNil() throws {
        // ignore
    }

    mutating func encode<T>(_ value: T) throws where T : Encodable {
        let key = BasicKey(codingPath.map { $0.stringValue }.joined(separator: ".") + "[]")
        let encoder = _FormDataEncoder(multipart: self.encoder.multipart, codingPath: [key])
        try value.encode(to: encoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let encoder = _FormDataEncoder(multipart: self.encoder.multipart, codingPath: codingPath)
        return KeyedEncodingContainer(_FormDataKeyedEncoder<NestedKey>(encoder))
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let encoder = _FormDataEncoder(multipart: self.encoder.multipart, codingPath: codingPath)
        return _FormDataUnkeyedEncoder(encoder)
    }

    mutating func superEncoder() -> Encoder {
        return _FormDataEncoder(multipart: encoder.multipart, codingPath: codingPath)
    }
}

private struct _FormDataKeyedEncoder<K>: KeyedEncodingContainerProtocol where K: CodingKey {
    let encoder: _FormDataEncoder

    var codingPath: [CodingKey] {
        return encoder.codingPath
    }

    init(_ encoder: _FormDataEncoder) {
        self.encoder = encoder
    }

    mutating func encodeNil(forKey key: K) throws {
        // ignore
    }

    mutating func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        let encoder = _FormDataEncoder(multipart: self.encoder.multipart, codingPath: codingPath + [key])
        try value.encode(to: encoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let encoder = _FormDataEncoder(multipart: self.encoder.multipart, codingPath: codingPath + [key])
        return KeyedEncodingContainer(_FormDataKeyedEncoder<NestedKey>(encoder))
    }

    mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        return _FormDataUnkeyedEncoder(encoder)
    }

    mutating func superEncoder() -> Encoder {
        return _FormDataEncoder(multipart: encoder.multipart, codingPath: codingPath)
    }

    mutating func superEncoder(forKey key: K) -> Encoder {
        return _FormDataEncoder(multipart: encoder.multipart, codingPath: codingPath + [key])
    }
}
