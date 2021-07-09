extension FormDataDecoder {
    struct Decoder {
        let codingPath: [CodingKey]
        let data: MultipartFormData
        let userInfo: [CodingUserInfoKey: Any]
    }
}

extension FormDataDecoder.Decoder: Decoder {
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard let dictionary = data.dictionary else {
            throw DecodingError.typeMismatch(data.dataType, .init(codingPath: codingPath, debugDescription: "expected dictionary but encountered \(data.dataTypeDescription)"))
        }
        return KeyedDecodingContainer(FormDataDecoder.KeyedContainer(codingPath: codingPath, data: dictionary, decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let array = data.array else {
            throw DecodingError.typeMismatch(data.dataType, .init(codingPath: codingPath, debugDescription: "expected array but encountered \(data.dataTypeDescription)"))
        }
        return FormDataDecoder.UnkeyedContainer(codingPath: codingPath, data: array, decoder: self)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        self
    }
}

extension FormDataDecoder.Decoder {
    func nested(at key: CodingKey, with data: MultipartFormData) -> Self {
        .init(codingPath: codingPath + [key], data: data, userInfo: userInfo)
    }
}

private extension MultipartFormData {
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
}
