extension FormDataEncoder {
    struct UnkeyedContainer<Body: MultipartPartBodyElement> where Body: RangeReplaceableCollection {
        let dataContainer = UnkeyedDataContainer<Body>()
        let encoder: FormDataEncoder.Encoder<Body>
    }
}

extension FormDataEncoder.UnkeyedContainer: UnkeyedEncodingContainer {
    var codingPath: [any CodingKey] {
        encoder.codingPath
    }

    var count: Int {
        dataContainer.value.count
    }

    func encodeNil() throws {
        // skip
    }

    func encode<T: Encodable>(_ value: T) throws {
        try nextEncoder().encode(value)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        nextEncoder().container(keyedBy: keyType)
    }

    func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        nextEncoder().unkeyedContainer()
    }

    func superEncoder() -> any Encoder {
        nextEncoder()
    }

    func nextEncoder() -> FormDataEncoder.Encoder<Body> {
        let encoder = self.encoder.nested(at: BasicCodingKey.index(count))
        dataContainer.value.append(encoder.storage)
        return encoder
    }
}
