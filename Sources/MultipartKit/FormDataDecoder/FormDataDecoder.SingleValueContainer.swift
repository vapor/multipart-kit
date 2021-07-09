extension FormDataDecoder.Decoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        false
    }

    func decode<T: Decodable>(_: T.Type = T.self) throws -> T {
        guard
            let part = data.part,
            let Convertible = T.self as? MultipartPartConvertible.Type
        else {
            if data.dictionary?.keys.isEmpty == true {
                throw DecodingError.valueNotFound(T.self, .init(codingPath: codingPath, debugDescription: "encountered empty dictionary"))
            }
            return try T(from: self)
        }

        guard
            let decoded = Convertible.init(multipart: part) as? T
        else {
            let path = codingPath.map(\.stringValue).joined(separator: ".")
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: codingPath,
                    debugDescription: #"could not convert value at "\#(path)" to type \#(T.self) from multipart part"#
                )
            )
        }
        return decoded
    }
}
