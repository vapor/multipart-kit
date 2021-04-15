/// Decodes `Decodable` types from `multipart/form-data` encoded `Data`.
///
/// See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
///
/// Seealso `MultipartParser` for more information about the `multipart` encoding.
public struct FormDataDecoder {
    /// Creates a new `FormDataDecoder`.
    public init() { }

    public func decode<D>(_ decodable: D.Type, from data: String, boundary: String) throws -> D
        where D: Decodable
    {
        return try self.decode(D.self, from: [UInt8](data.utf8), boundary: boundary)
    }

    /// Decodes a `Decodable` item from `Data` using the supplied boundary.
    ///
    ///     let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "123")
    ///
    /// - parameters:
    ///     - encodable: Generic `Decodable` type.
    ///     - boundary: Multipart boundary to used in the encoding.
    /// - throws: Any errors decoding the model with `Codable` or parsing the data.
    /// - returns: An instance of the decoded type `D`.
    public func decode<D>(_ decodable: D.Type, from data: [UInt8], boundary: String) throws -> D
        where D: Decodable
    {
        let parser = MultipartParser(boundary: boundary)

        var parts: [MultipartPart] = []
        var headers: HTTPHeaders = .init()
        var body: ByteBuffer = ByteBuffer()

        parser.onHeader = { (field, value) in
            headers.replaceOrAdd(name: field, value: value)
        }
        parser.onBody = { new in
            body.writeBuffer(&new)
        }
        parser.onPartComplete = {
            let part = MultipartPart(headers: headers, body: body)
            headers = [:]
            body = ByteBuffer()
            parts.append(part)
        }

        try parser.execute(data)
        let data = MultipartFormData(parts: parts)
        let decoder = _FormDataDecoder(codingPath: [], data: data)
        return try D(from: decoder)
    }
}

// MARK: Private

private struct _FormDataDecoder: Decoder {
    var codingPath: [CodingKey]
    let data: MultipartFormData

    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        KeyedDecodingContainer(_FormDataKeyedDecoder<Key>(codingPath: codingPath, data: data.dictionary))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        _FormDataUnkeyedDecoder(codingPath: codingPath, data: data.array)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        // must coding path be empty?
        _FormDataSingleValueDecoder(codingPath: codingPath, part: data.part)
    }
}

extension MultipartPart {
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        guard let convertible = T.self as? MultipartPartConvertible.Type else {
            throw MultipartError.convertibleType(T.self)
        }
        return convertible.init(multipart: self) as! T
    }
}

private struct _FormDataSingleValueDecoder: SingleValueDecodingContainer {
    var codingPath: [CodingKey]
    let part: MultipartPart?

    func decodeNil() -> Bool {
        part == nil
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        guard let part = part else {
            // TODO: description
            throw DecodingError.valueNotFound(T.self, .init(codingPath: codingPath, debugDescription: ""))
        }
        return try part.decode(T.self)
    }
}

private struct _FormDataKeyedDecoder<K>: KeyedDecodingContainerProtocol where K: CodingKey {
    let codingPath: [CodingKey]
    var allKeys: [K] {
        data.keys.compactMap(K.init(stringValue:))
    }

    let data: MultipartFormData.Keyed

    func contains(_ key: K) -> Bool {
        data.keys.contains(key.stringValue)
    }

    func getValue(forKey key: K) throws -> MultipartFormData {
        guard let value = data[key.stringValue] else {
            // TODO: add description
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
        }
        return value
    }

    func decodeNil(forKey key: K) throws -> Bool {
        // TODO: is this a good way to represent null?
        return try getValue(forKey: key) == .single(.init(body: "null"))
    }

    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T : Decodable {
        let value = try getValue(forKey: key)

        if T.self is MultipartPartConvertible.Type {
            guard let part = value.part else {
                // TODO:
                throw MultipartError.missingPart("Asdads")
            }
            return try part.decode(T.self)

        } else {
            let decoder = _FormDataDecoder(codingPath: codingPath + [key], data: data[key.stringValue]!)
            return try T(from: decoder)
        }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try KeyedDecodingContainer(_FormDataKeyedDecoder<NestedKey>(codingPath: codingPath + [key], data: getValue(forKey: key).dictionary))
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        try _FormDataUnkeyedDecoder(codingPath: codingPath + [key], data: getValue(forKey: key).array)
    }

    func superDecoder() throws -> Decoder {
        _FormDataDecoder(codingPath: codingPath, data: .keyed(data))
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        _FormDataDecoder(codingPath: codingPath + [key], data: .keyed([key.stringValue: .keyed(data)]))
    }
}

private struct _FormDataUnkeyedDecoder: UnkeyedDecodingContainer {
//    init(codingPath: [CodingKey], data: MultipartFormData) {
//        self.data =
//    }

    var isAtEnd: Bool { currentIndex >= data.count }

    var currentIndex: Int = 0

    var codingPath: [CodingKey]
    var count: Int? { data.count }

    var index: CodingKey { BasicCodingKey.index(currentIndex) }

    var data: [MultipartFormData]

    mutating func decodeNil() throws -> Bool {
        false
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        defer { currentIndex += 1 }
        let current = data[currentIndex]
        if T.self is MultipartPartConvertible.Type {
            // TODO: !
            return try current.part!.decode(T.self)
        } else {
            let decoder = _FormDataDecoder(codingPath: codingPath + [index], data: current)
            return try T(from: decoder)
        }
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        KeyedDecodingContainer(_FormDataKeyedDecoder<NestedKey>(codingPath: codingPath + [index], data: data[currentIndex].dictionary))
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        _FormDataUnkeyedDecoder(codingPath: codingPath + [index], data: data)
    }

    mutating func superDecoder() throws -> Decoder {
        _FormDataDecoder(codingPath: codingPath + [index], data: .array(data))
    }
}
