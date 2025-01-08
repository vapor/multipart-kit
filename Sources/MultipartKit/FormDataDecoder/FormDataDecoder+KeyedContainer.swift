extension FormDataDecoder {
    struct KeyedContainer<K: CodingKey, Body: MultipartPartBodyElement> {
        let data: MultipartFormData<Body>.Keyed
        let decoder: FormDataDecoder.Decoder<Body>
    }
}

extension FormDataDecoder.KeyedContainer: KeyedDecodingContainerProtocol {
    var allKeys: [K] {
        data.keys.compactMap(K.init(stringValue:))
    }

    var codingPath: [any CodingKey] {
        decoder.codingPath
    }

    func contains(_ key: K) -> Bool {
        data.keys.contains(key.stringValue)
    }

    func getValue(forKey key: any CodingKey) throws -> MultipartFormData<Body> {
        guard let value = data[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                .init(
                    codingPath: codingPath,
                    debugDescription: "No value associated with key \"\(key.stringValue)\"."
                )
            )
        }
        return value
    }

    func decodeNil(forKey key: K) throws -> Bool {
        false
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        try decoderForKey(key).decode()
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
        try decoderForKey(key).container(keyedBy: keyType)
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> any UnkeyedDecodingContainer {
        try decoderForKey(key).unkeyedContainer()
    }

    func superDecoder() throws -> any Decoder {
        try decoderForKey(BasicCodingKey.super)
    }

    func superDecoder(forKey key: K) throws -> any Decoder {
        try decoderForKey(key)
    }

    func decoderForKey(_ key: any CodingKey) throws -> FormDataDecoder.Decoder<Body> {
        decoder.nested(at: key, with: try getValue(forKey: key))
    }
}
