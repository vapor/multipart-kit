#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public protocol FormDataNamedEncodable: Encodable {}

extension Dictionary: FormDataNamedEncodable where Key == String, Value: Encodable {}
extension Array: FormDataNamedEncodable where Element: Encodable {}
extension Optional: FormDataNamedEncodable where Wrapped: FormDataNamedEncodable {}

public protocol FormDataNamedDecodable: Decodable {}

extension Dictionary: FormDataNamedDecodable where Key == String, Value: Decodable {}
extension Array: FormDataNamedDecodable where Element: Decodable {}
extension Optional: FormDataNamedDecodable where Wrapped: FormDataNamedDecodable {}

public typealias FormDataNamedCodable = FormDataNamedEncodable & FormDataNamedDecodable

@available(*, unavailable)
extension Int: FormDataNamedCodable {}
@available(*, unavailable)
extension Int8: FormDataNamedCodable {}
@available(*, unavailable)
extension Int16: FormDataNamedCodable {}
@available(*, unavailable)
extension Int32: FormDataNamedCodable {}
@available(*, unavailable)
extension Int64: FormDataNamedCodable {}
@available(*, unavailable)
extension Int128: FormDataNamedCodable {}
@available(*, unavailable)
extension UInt: FormDataNamedCodable {}
@available(*, unavailable)
extension UInt8: FormDataNamedCodable {}
@available(*, unavailable)
extension UInt16: FormDataNamedCodable {}
@available(*, unavailable)
extension UInt32: FormDataNamedCodable {}
@available(*, unavailable)
extension UInt64: FormDataNamedCodable {}
@available(*, unavailable)
extension UInt128: FormDataNamedCodable {}
@available(*, unavailable)
extension Float: FormDataNamedCodable {}
@available(*, unavailable)
extension Double: FormDataNamedCodable {}
@available(*, unavailable)
extension String: FormDataNamedCodable {}
@available(*, unavailable)
extension Bool: FormDataNamedCodable {}
@available(*, unavailable)
extension Data: FormDataNamedCodable {}
@available(*, unavailable)
extension URL: FormDataNamedCodable {}
