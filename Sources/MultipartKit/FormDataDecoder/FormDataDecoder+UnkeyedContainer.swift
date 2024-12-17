extension FormDataDecoder {
    struct UnkeyedContainer<Body: MultipartPartBodyElement> {
        var currentIndex: Int = 0
        let data: [MultipartFormData<Body>]
        let decoder: FormDataDecoder.Decoder<Body>
    }
}

extension FormDataDecoder.UnkeyedContainer: UnkeyedDecodingContainer {
    var codingPath: [any CodingKey] {
        decoder.codingPath
    }
    var count: Int? { data.count }
    var index: any CodingKey { BasicCodingKey.index(currentIndex) }
    var isAtEnd: Bool { currentIndex >= data.count }

    mutating func decodeNil() throws -> Bool {
        false
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try decoderAtIndex().decode(T.self)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        try decoderAtIndex().container(keyedBy: keyType)
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        try decoderAtIndex().unkeyedContainer()
    }

    mutating func superDecoder() throws -> any Decoder {
        try decoderAtIndex()
    }

    mutating func decoderAtIndex() throws -> FormDataDecoder.Decoder<Body> {
        defer { currentIndex += 1 }
        return try decoder.nested(at: index, with: getValue())
    }

    mutating func getValue() throws -> MultipartFormData<Body> {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                FormDataDecoder.Decoder<Body>.self,
                .init(
                    codingPath: codingPath,
                    debugDescription: "Unkeyed container is at end.",
                    underlyingError: nil
                )
            )
        }
        return data[currentIndex]
    }
}
