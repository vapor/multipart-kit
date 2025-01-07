#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

extension FormDataEncoder.Encoder: SingleValueEncodingContainer {
    func encodeNil() throws {
        // skip
    }

    private func encodeInteger<T: FixedWidthInteger>(_ value: T) throws {
        storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(value.description.utf8)))
    }

    func encode(_ value: Int) throws { try encodeInteger(value) }
    func encode(_ value: Int8) throws { try encodeInteger(value) }
    func encode(_ value: Int16) throws { try encodeInteger(value) }
    func encode(_ value: Int32) throws { try encodeInteger(value) }
    func encode(_ value: Int64) throws { try encodeInteger(value) }
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    func encode(_ value: Int128) throws { try encodeInteger(value) }
    func encode(_ value: UInt) throws { try encodeInteger(value) }
    func encode(_ value: UInt8) throws { try encodeInteger(value) }
    func encode(_ value: UInt16) throws { try encodeInteger(value) }
    func encode(_ value: UInt32) throws { try encodeInteger(value) }
    func encode(_ value: UInt64) throws { try encodeInteger(value) }
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    func encode(_ value: UInt128) throws { try encodeInteger(value) }

    func encode(_ value: Float) throws {
        storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(value.description.utf8)))
    }

    func encode(_ value: Double) throws {
        storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(value.description.utf8)))
    }

    func encode(_ value: String) throws {
        storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(value.utf8)))
    }

    func encode(_ value: Bool) throws {
        storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(value.description.utf8)))
    }

    func encode<T: Encodable>(_ value: T) throws {
        switch value {
        case let multipart as MultipartPart<Body>:
            storage.dataContainer = SingleValueDataContainer(part: multipart)
        case let data as Data:
            storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(data)))
        case let url as URL:
            storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(url.absoluteString.utf8)))
        default:
            try value.encode(to: self)
        }
    }
}
