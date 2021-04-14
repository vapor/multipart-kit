import struct NIO.ByteBufferAllocator

/// Encodes `Encodable` items to `multipart/form-data` encoded `Data`.
///
/// See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
///
/// Seealso `MultipartParser` for more information about the `multipart` encoding.
public struct FormDataEncoder {
    /// Creates a new `FormDataEncoder`.
    public init() { }

    public func encode<E>(_ encodable: E, boundary: String) throws -> String
        where E: Encodable
    {
        let encoder = _Encoder(codingPath: [])
        try encodable.encode(to: encoder)
        return try MultipartSerializer().serialize(parts: encoder.getData().namedParts(), boundary: boundary)
    }

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
    public func encode<E>(_ encodable: E, boundary: String, into buffer: inout ByteBuffer) throws
        where E: Encodable
    {
        let encoder = _Encoder(codingPath: [])
        try encodable.encode(to: encoder)
        try MultipartSerializer().serialize(parts: encoder.getData().namedParts(), boundary: boundary, into: &buffer)
    }
}

// MARK: - Private

// MARK: MultipartFormData

private enum MultipartFormData {
    case single(MultipartPart)
    case array([MultipartFormData])
    case keyed([(String, MultipartFormData)])

    func namedParts() -> [MultipartPart] {
        Self.namedParts(from: self)
    }

    static func namedParts(from data: MultipartFormData, path: String? = nil) -> [MultipartPart] {
        switch data {
        case .array(let array):
            return array.flatMap { namedParts(from: $0, path: path.map { "\($0)[]" }) }
        case .single(var part):
            part.name = path
            return [part]
        case .keyed(let keysAndValues):
            return keysAndValues.flatMap { key, value in
                namedParts(from: value, path: path.map { "\($0)[\(key)]" } ?? key)
            }
        }
    }
}

// MARK: _Container

private protocol _Container {
    func getData() -> MultipartFormData
}

// MARK: _Encoder

private final class _Encoder {
    init(codingPath: [CodingKey]) {
        self.codingPath = codingPath
    }
    private var container: _Container? = nil
    var codingPath: [CodingKey]
}

extension _Encoder: Encoder {
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
        where Key: CodingKey
    {
        let container = KeyedContainer<Key>(codingPath: codingPath)
        self.container = container
        return .init(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let container = UnkeyedContainer(codingPath: codingPath)
        self.container = container
        return container
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        let container = SingleValueContainer(codingPath: codingPath)
        self.container = container
        return container
    }
}

extension _Encoder: _Container {
    func getData() -> MultipartFormData {
        container?.getData() ?? .array([])
    }
}

// MARK: _Encoder.KeyedContainer

extension _Encoder {
    final class KeyedContainer<Key> where Key: CodingKey {
        var codingPath: [CodingKey]
        var data: [(String, DataOrContainer)] = []

        init(codingPath: [CodingKey]) {
            self.codingPath = codingPath
        }
    }
}

extension _Encoder.KeyedContainer: KeyedEncodingContainerProtocol {
    func encodeNil(forKey _: Key) throws {
        // skip
    }

    func encode<T>(_ value: T, forKey key: Key) throws
        where T : Encodable
    {
        if let convertible = value as? MultipartPartConvertible {
            if let part = convertible.multipart {
                data.append((key.stringValue, .data(.single(part))))
            }
        } else {
            let encoder = _Encoder(codingPath: codingPath + [key])
            try value.encode(to: encoder)
            data.append((key.stringValue, .data(encoder.getData())))
        }
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        let container = _Encoder.KeyedContainer<NestedKey>(codingPath: codingPath + [key])
        data.append((key.stringValue, .container(container)))
        return .init(container)
    }

    /// See `KeyedEncodingContainerProtocol`
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let container = _Encoder.UnkeyedContainer(codingPath: codingPath + [key])
        data.append((key.stringValue, .container(container)))
        return container
    }

    func superEncoder() -> Encoder {
        fatalError()
    }

    func superEncoder(forKey key: Key) -> Encoder {
        fatalError()
    }
}

extension _Encoder.KeyedContainer: _Container {
    fileprivate func getData() -> MultipartFormData {
        .keyed(data.map { key, value in (key, value.data) })
    }
}

private enum DataOrContainer {
    case data(MultipartFormData)
    case container(_Container)

    var data: MultipartFormData {
        switch self {
        case .container(let container):
            return container.getData()
        case .data(let data):
            return data
        }
    }
}

// MARK: _Encoder.UnkeyedContainer

extension _Encoder {
    final class UnkeyedContainer {
        var codingPath: [CodingKey]
        var data: [DataOrContainer] = []

        init(codingPath: [CodingKey]) {
            self.codingPath = codingPath
        }
    }
}

extension _Encoder.UnkeyedContainer: UnkeyedEncodingContainer {
    var count: Int { data.count }

    func encodeNil() throws {
        // skip
    }

    func encode<T>(_ value: T) throws
        where T : Encodable
    {
        if let convertible = value as? MultipartPartConvertible {
            if let part = convertible.multipart {
                data.append(.data(.single(part)))
            }
        } else {
            let encoder = _Encoder(codingPath: codingPath)
            try value.encode(to: encoder)
            data.append(.data(encoder.getData()))
        }
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
        where NestedKey: CodingKey
    {
        let container = _Encoder.KeyedContainer<NestedKey>(codingPath: codingPath)
        data.append(.container(container))
        return .init(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = _Encoder.UnkeyedContainer(codingPath: codingPath)
        data.append(.container(container))
        return container
    }

    func superEncoder() -> Encoder {
        fatalError()
    }
}

extension _Encoder.UnkeyedContainer: _Container {
    fileprivate func getData() -> MultipartFormData {
        .array(data.map(\.data))
    }
}

// MARK: _Encoder.SingleValueContainer

extension _Encoder {
    final class SingleValueContainer {
        var codingPath: [CodingKey]
        var data: MultipartFormData?

        init(codingPath: [CodingKey]) {
            self.codingPath = codingPath
        }
    }
}

extension _Encoder.SingleValueContainer: SingleValueEncodingContainer {
    func encodeNil() throws {
        // skip
    }

    func encode<T>(_ value: T) throws
        where T : Encodable
    {
        if let convertible = value as? MultipartPartConvertible {
            if let part = convertible.multipart {
                data = .single(part)
            }
        } else {
            let encoder = _Encoder(codingPath: codingPath)
            try value.encode(to: encoder)
            data = encoder.getData()
        }
    }
}

extension _Encoder.SingleValueContainer: _Container {
    fileprivate func getData() -> MultipartFormData {
        data ?? .keyed([])
    }
}
