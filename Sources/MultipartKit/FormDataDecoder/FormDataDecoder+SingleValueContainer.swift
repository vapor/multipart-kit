#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

extension FormDataDecoder.Decoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        false
    }

    func decode<T: Decodable>(_: T.Type = T.self) throws -> T {
        guard let part = data.part else {
            guard previousCodingPath?.count != codingPath.count || previousType != T.self else {
                throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Decoding caught in recursion loop"))
            }

            return try T(
                from: FormDataDecoder.Decoder(
                    codingPath: codingPath, data: data, userInfo: sendableUserInfo, previousCodingPath: codingPath, previousType: T.self
                )
            )
        }

        let decoded =
            switch T.self {
            case is MultipartPart<Body>.Type:
                part as? T
            case is String.Type:
                String(bytes: part.body, encoding: .utf8) as? T
            case let IntType as any FixedWidthInteger.Type:
                String(bytes: part.body, encoding: .utf8).flatMap(IntType.init) as? T
            case is Float.Type:
                String(bytes: part.body, encoding: .utf8).flatMap(Float.init) as? T
            case is Double.Type:
                String(bytes: part.body, encoding: .utf8).flatMap(Double.init) as? T
            case is Bool.Type:
                String(bytes: part.body, encoding: .utf8).flatMap(Bool.init) as? T
            case is Data.Type:
                Data(part.body) as? T
            case is URL.Type:
                String(bytes: part.body, encoding: .utf8).flatMap(URL.init(string:)) as? T
            default:
                T?.none
            }

        guard let decoded else {
            guard !data.hasExceededNestingDepth else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: codingPath, debugDescription: "Nesting depth exceeded.", underlyingError: nil)
                )
            }

            return try T(
                from: FormDataDecoder.Decoder(
                    codingPath: codingPath, data: data, userInfo: sendableUserInfo, previousCodingPath: codingPath, previousType: T.self
                )
            )
        }

        return decoded
    }
}
