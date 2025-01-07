#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

extension FormDataDecoder.Decoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        false
    }

    func decode(_: Bool.Type) throws -> Bool {
        guard
            let part = data.part,
            let decoded = Bool(String(decoding: part.body, as: UTF8.self))
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Could not decode Bool."))
        }

        return decoded
    }

    private func decodeInteger<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        guard
            let part = data.part,
            let decoded = T(String(decoding: part.body, as: UTF8.self))
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Could not decode \(type)."))
        }
        return decoded
    }

    func decode(_: Int.Type) throws -> Int { try decodeInteger(Int.self) }
    func decode(_: Int8.Type) throws -> Int8 { try decodeInteger(Int8.self) }
    func decode(_: Int16.Type) throws -> Int16 { try decodeInteger(Int16.self) }
    func decode(_: Int32.Type) throws -> Int32 { try decodeInteger(Int32.self) }
    func decode(_: Int64.Type) throws -> Int64 { try decodeInteger(Int64.self) }
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    func decode(_ type: Int128.Type) throws -> Int128 { try decodeInteger(Int128.self) }
    func decode(_: UInt.Type) throws -> UInt { try decodeInteger(UInt.self) }
    func decode(_: UInt8.Type) throws -> UInt8 { try decodeInteger(UInt8.self) }
    func decode(_: UInt16.Type) throws -> UInt16 { try decodeInteger(UInt16.self) }
    func decode(_: UInt32.Type) throws -> UInt32 { try decodeInteger(UInt32.self) }
    func decode(_: UInt64.Type) throws -> UInt64 { try decodeInteger(UInt64.self) }
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    func decode(_ type: UInt128.Type) throws -> UInt128 { try decodeInteger(UInt128.self) }

    func decode(_: Float.Type) throws -> Float {
        guard
            let part = data.part,
            let decoded = Float(String(decoding: part.body, as: UTF8.self))
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Could not decode Float."))
        }

        return decoded
    }

    func decode(_: Double.Type) throws -> Double {
        guard
            let part = data.part,
            let decoded = Double(String(decoding: part.body, as: UTF8.self))
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Could not decode Double."))
        }

        return decoded
    }

    func decode(_: String.Type) throws -> String {
        guard
            let part = data.part,
            let decoded = String(bytes: part.body, encoding: .utf8)
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Could not decode String."))
        }

        return decoded
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
            case is Data.Type:
                Data(part.body) as? T
            case is URL.Type:
                URL(string: String(decoding: part.body, as: UTF8.self)) as? T
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
