/// A protocol to provide custom behaviors for parsing and serializing types from and to multipart data.

public protocol MultipartPartEncodable {
    associatedtype Body: MultipartPartBodyElement

    var multipart: MultipartPart<Body> { get throws }
}

public protocol MultipartPartDecodable {
    associatedtype Body: MultipartPartBodyElement

    init(multipart: MultipartPart<Body>) throws
}

public typealias MultipartPartConvertible = MultipartPartEncodable & MultipartPartDecodable

extension MultipartPart: MultipartPartConvertible {
    public var multipart: MultipartPart<Body> {
        self
    }

    public init(multipart: MultipartPart<some MultipartPartBodyElement>) {
        self = .init(headerFields: multipart.headerFields, body: .init(multipart.body))
    }
}
