extension FormDataEncoder {
    struct KeyedContainer<Key: CodingKey> {
        let dataContainer = KeyedDataContainer()
        let encoder: Encoder
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

    func encoderForKey(_ key: any CodingKey) -> FormDataEncoder.Encoder {
        let encoder = self.encoder.nested(at: key)
        dataContainer.value[key.stringValue] = encoder.storage
        return encoder
    }
}
