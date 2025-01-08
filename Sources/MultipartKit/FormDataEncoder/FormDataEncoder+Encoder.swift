extension FormDataEncoder {
    struct Encoder<Body: MultipartPartBodyElement> where Body: RangeReplaceableCollection {
        let codingPath: [any CodingKey]
        let storage = Storage<Body>()
        let sendableUserInfo: [CodingUserInfoKey: any Sendable]

        var userInfo: [CodingUserInfoKey: Any] { sendableUserInfo }

        init(codingPath: [any CodingKey] = [], userInfo: [CodingUserInfoKey: any Sendable] = [:]) {
            self.codingPath = codingPath
            self.sendableUserInfo = userInfo
        }
    }
}

extension FormDataEncoder.Encoder: Encoder {
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = FormDataEncoder.KeyedContainer<Key, Body>(encoder: self)
        storage.dataContainer = container.dataContainer
        return .init(container)
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        let container = FormDataEncoder.UnkeyedContainer<Body>(encoder: self)
        storage.dataContainer = container.dataContainer
        return container
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        self
    }
}

extension FormDataEncoder.Encoder {
    func nested(at key: any CodingKey) -> FormDataEncoder.Encoder<Body> {
        .init(codingPath: codingPath + [key], userInfo: sendableUserInfo)
    }
}
