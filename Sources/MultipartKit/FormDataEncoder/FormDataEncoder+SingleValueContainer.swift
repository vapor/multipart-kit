#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension FormDataEncoder.Encoder: SingleValueEncodingContainer {
    func encodeNil() throws {
        // skip
    }

    func encode<T: Encodable>(_ value: T) throws {
        switch value {
        case let multipart as MultipartPart<Body>:
            storage.dataContainer = SingleValueDataContainer(part: multipart)
        case let string as String:
            storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(string.utf8)))
        case let int as any FixedWidthInteger:
            storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(int.description.utf8)))
        case let float as Float:
            storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(float.description.utf8)))
        case let double as Double:
            storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(double.description.utf8)))
        case let bool as Bool:
            storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(bool.description.utf8)))
        case let data as Data:
            storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(data)))
        case let url as URL:
            storage.dataContainer = SingleValueDataContainer(part: .init(headerFields: [:], body: Body(url.absoluteString.utf8)))
        default:
            try value.encode(to: self)
        }
    }
}
