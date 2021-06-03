/// Decodes `Decodable` types from `multipart/form-data` encoded `Data`.
///
/// See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
///
/// Seealso `MultipartParser` for more information about the `multipart` encoding.
public struct FormDataDecoder {
    /// Maximum nesting depth to allow when decoding the input.
    /// - 1 corresponds to a single value
    /// - 2 corresponds to an an object with non-nested properties or an 1 dimensional array
    /// - 3... corresponds to nested objects or multi-dimensional arrays or combinations thereof
    let nestingDepth: Int

    /// Creates a new `FormDataDecoder`.
    /// - Parameter nestingDepth: maximum allowed nesting depth of the decoded structure. Defaults to 8.
    public init(nestingDepth: Int = 8) {
        self.nestingDepth = nestingDepth
    }

    /// Decodes a `Decodable` item from `String` using the supplied boundary.
    ///
    ///     let foo = try FormDataDecoder().decode(Foo.self, from: "...", boundary: "123")
    ///
    /// - Parameters:
    ///   - decodable: Generic `Decodable` type.
    ///   - data: String to decode.
    ///   - boundary: Multipart boundary to used in the decoding.
    /// - Throws: Any errors decoding the model with `Codable` or parsing the data.
    /// - Returns: An instance of the decoded type `D`.
    public func decode<D>(_ decodable: D.Type, from data: String, boundary: String) throws -> D
        where D: Decodable
    {
        return try self.decode(D.self, from: [UInt8](data.utf8), boundary: boundary)
    }

    /// Decodes a `Decodable` item from `Data` using the supplied boundary.
    ///
    ///     let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "123")
    ///
    /// - Parameters:
    ///   - decodable: Generic `Decodable` type.
    ///   - data: Data to decode.
    ///   - boundary: Multipart boundary to used in the decoding.
    /// - Throws: Any errors decoding the model with `Codable` or parsing the data.
    /// - Returns: An instance of the decoded type `D`.
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
        let data = MultipartFormData(parts: parts, nestingDepth: nestingDepth)
        return try data.decode(codingPath: [])
    }
}

// MARK: Private

private struct _FormDataDecoder: Decoder {
    let codingPath: [CodingKey]
    let data: MultipartFormData

    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        try data.keyedContainer(codingPath: codingPath)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        try data.unkeyedContainer(codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        try data.singleValueContainer(codingPath: codingPath)
    }
}

private struct _FormDataSingleValueDecoder: SingleValueDecodingContainer {
    var codingPath: [CodingKey]
    let part: MultipartPart

    func decodeNil() -> Bool {
        false
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        guard
            let Convertible = T.self as? MultipartPartConvertible.Type,
            let decoded = Convertible.init(multipart: part) as? T
        else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "Could not convert value at \(codingPath) from multipart part.")
        }
        return decoded
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
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
        }
        return value
    }

    func decodeNil(forKey key: K) throws -> Bool {
        false
    }

    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T : Decodable {
        try getValue(forKey: key).decode(codingPath: codingPath + [key])
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try getValue(forKey: key).keyedContainer(codingPath: codingPath + [key])
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        try getValue(forKey: key).unkeyedContainer(codingPath: codingPath + [key])
    }

    func superDecoder() throws -> Decoder {
        fatalError()
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        fatalError()
    }
}

private struct _FormDataUnkeyedDecoder: UnkeyedDecodingContainer {
    var index: CodingKey { BasicCodingKey.index(currentIndex) }
    var isAtEnd: Bool { currentIndex >= data.count }
    var codingPath: [CodingKey]
    var count: Int? { data.count }
    var currentIndex: Int = 0
    var data: [MultipartFormData]

    mutating func decodeNil() throws -> Bool {
        false
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        defer { currentIndex += 1 }
        return try data[currentIndex].decode(codingPath: codingPath + [index])
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try data[currentIndex].keyedContainer(codingPath: codingPath + [index])
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try data[currentIndex].unkeyedContainer(codingPath: codingPath)
    }

    func superDecoder() throws -> Decoder {
        fatalError()
    }
}

private extension MultipartFormData {
    func keyedContainer<Key: CodingKey>(codingPath: [CodingKey]) throws -> KeyedDecodingContainer<Key> {
        guard let dictionary = self.dictionary else {
            throw DecodingError.typeMismatch(dataType, .init(codingPath: codingPath, debugDescription: "expected dictionary but encountered \(dataTypeDescription)"))
        }
        return KeyedDecodingContainer(_FormDataKeyedDecoder(codingPath: codingPath, data: dictionary))
    }

    func unkeyedContainer(codingPath: [CodingKey]) throws -> UnkeyedDecodingContainer {
        guard let array = self.array else {
            throw DecodingError.typeMismatch(dataType, .init(codingPath: codingPath, debugDescription: "expected array but encountered \(dataTypeDescription)"))
        }
        return _FormDataUnkeyedDecoder(codingPath: codingPath, data: array)
    }

    func singleValueContainer(codingPath: [CodingKey]) throws -> SingleValueDecodingContainer {
        guard let part = self.part else {
            throw DecodingError.typeMismatch(dataType, .init(codingPath: codingPath, debugDescription: "expected single value but encountered \(dataTypeDescription)"))
        }
        return _FormDataSingleValueDecoder(codingPath: codingPath, part: part)
    }

    var dataTypeDescription: String {
        switch self {
        case .array: return "array"
        case .keyed: return "dictionary"
        case .single: return "single value"
        }
    }

    var dataType: Any.Type {
        switch self {
        case .array: return [MultipartFormData].self
        case .keyed: return Keyed.self
        case .single: return MultipartPart.self
        }
    }

    func decode<T>(codingPath: [CodingKey]) throws -> T where T: Decodable {
        guard
            let Convertible = T.self as? MultipartPartConvertible.Type,
            let part = self.part
        else {
            return try T(from: _FormDataDecoder(codingPath: codingPath, data: self))
        }
        guard
            let converted = Convertible.init(multipart: part) as! T?
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Could not initialize \(T.self) from MultipartPart"))
        }
        return converted
    }
}
