public protocol FormDataNamedEncodable: Encodable {}

extension Dictionary: FormDataNamedEncodable where Key == String, Value: Encodable {}
extension Array: FormDataNamedEncodable where Element: Encodable {}
extension Optional: FormDataNamedEncodable where Wrapped: FormDataNamedEncodable {}

public protocol FormDataNamedDecodable: Decodable {}

extension Dictionary: FormDataNamedDecodable where Key == String, Value: Decodable {}
extension Array: FormDataNamedDecodable where Element: Decodable {}
extension Optional: FormDataNamedDecodable where Wrapped: FormDataNamedDecodable {}

public typealias FormDataNamedCodable = FormDataNamedEncodable & FormDataNamedDecodable
