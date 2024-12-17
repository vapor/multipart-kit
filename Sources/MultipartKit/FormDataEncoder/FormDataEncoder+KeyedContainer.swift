extension FormDataEncoder {
    struct KeyedContainer<Key: CodingKey, Body: MultipartPartBodyElement> where Body: RangeReplaceableCollection {
        let dataContainer = KeyedDataContainer<Body>()
        let encoder: Encoder<Body>
    }
}

extension FormDataEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
    var codingPath: [any CodingKey] {
        encoder.codingPath
    }

    func encodeNil(forKey _: Key) throws {
        // skip
    }

    func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        try encoderForKey(key).encode(value)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        encoderForKey(key).container(keyedBy: keyType)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        encoderForKey(key).unkeyedContainer()
    }

    func superEncoder() -> any Encoder {
        encoderForKey(BasicCodingKey.super)
    }

    func superEncoder(forKey key: Key) -> any Encoder {
        encoderForKey(key)
    }

    func encoderForKey(_ key: any CodingKey) -> FormDataEncoder.Encoder<Body> {
        let encoder = self.encoder.nested(at: key)
        dataContainer.value[key.stringValue] = encoder.storage
        return encoder
    }
}
