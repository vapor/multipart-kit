extension FormDataDecoder {
    struct UnkeyedContainer {
        let codingPath: [CodingKey]
        var currentIndex: Int = 0
        let data: [MultipartFormData]
        let decoder: FormDataDecoder.Decoder
    }
}

extension FormDataDecoder.UnkeyedContainer: UnkeyedDecodingContainer {
    var index: CodingKey { BasicCodingKey.index(currentIndex) }
    var isAtEnd: Bool { currentIndex >= data.count }
    var count: Int? { data.count }

    mutating func decodeNil() throws -> Bool {
        false
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        try decoderForIndex().decode(T.self)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try decoderForIndex().container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try decoderForIndex().unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
        decoderForIndex()
    }

    mutating func decoderForIndex() -> FormDataDecoder.Decoder {
        defer { currentIndex += 1 }
        return decoder.nested(at: index, with: data[currentIndex])
    }
}
