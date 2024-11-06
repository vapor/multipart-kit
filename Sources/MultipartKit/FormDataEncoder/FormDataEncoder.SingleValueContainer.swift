extension FormDataEncoder.Encoder: SingleValueEncodingContainer {
    func encodeNil() throws {
        // skip
    }

    func encode<T: Encodable>(_ value: T) throws {
        if let convertible = value as? any MultipartPartConvertible<[UInt8]>,
            let part = convertible.multipart
        {
            storage.dataContainer = SingleValueDataContainer(part: part)
        } else {
            try value.encode(to: self)
        }
    }
}
