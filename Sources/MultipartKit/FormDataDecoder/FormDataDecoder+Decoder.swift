extension FormDataDecoder {
    struct Decoder<Body: MultipartPartBodyElement> {
        let codingPath: [any CodingKey]
        let data: MultipartFormData<Body>
        let sendableUserInfo: [CodingUserInfoKey: any Sendable]
        let previousCodingPath: [any CodingKey]?
        let previousType: (any Decodable.Type)?

        var userInfo: [CodingUserInfoKey: Any] { sendableUserInfo }

        init(
            codingPath: [any CodingKey],
            data: MultipartFormData<Body>,
            userInfo: [CodingUserInfoKey: any Sendable] = [:],
            previousCodingPath: [any CodingKey]? = nil,
            previousType: (any Decodable.Type)? = nil
        ) {
            self.codingPath = codingPath
            self.data = data
            self.sendableUserInfo = userInfo
            self.previousCodingPath = previousCodingPath
            self.previousType = previousType
        }
    }
}

extension FormDataDecoder.Decoder: Decoder {
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard let dictionary = data.dictionary else {
            throw decodingError(expectedType: "dictionary")
        }
        return KeyedDecodingContainer(FormDataDecoder.KeyedContainer(data: dictionary, decoder: self))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        guard let array = data.array else {
            throw decodingError(expectedType: "array")
        }
        return FormDataDecoder.UnkeyedContainer(data: array, decoder: self)
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        self
    }
}

extension FormDataDecoder.Decoder {
    func nested(at key: any CodingKey, with data: MultipartFormData<Body>) -> Self {
        .init(codingPath: codingPath + [key], data: data, userInfo: sendableUserInfo)
    }
}

extension FormDataDecoder.Decoder {
    fileprivate func decodingError(expectedType: String) -> any Error {
        let encounteredType: Any.Type
        let encounteredTypeDescription: String

        switch data {
        case .nestingDepthExceeded:
            return DecodingError.dataCorrupted(
                .init(
                    codingPath: codingPath,
                    debugDescription: "Nesting depth exceeded while expecting \(expectedType).",
                    underlyingError: nil
                ))
        case .array:
            encounteredType = [MultipartFormData<Body>].self
            encounteredTypeDescription = "array"
        case .keyed:
            encounteredType = MultipartFormData<Body>.Keyed.self
            encounteredTypeDescription = "dictionary"
        case .single:
            encounteredType = MultipartPart<Body>.self
            encounteredTypeDescription = "single value"
        }

        return DecodingError.typeMismatch(
            encounteredType,
            .init(
                codingPath: codingPath,
                debugDescription: "Expected \(expectedType) but encountered \(encounteredTypeDescription).",
                underlyingError: nil
            )
        )
    }
}
