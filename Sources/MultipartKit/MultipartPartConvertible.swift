/// A type that can be converted to a `MultipartPart`.
public protocol MultipartPartEncodable<Body> {
    associatedtype Body: MultipartPartBodyElement

    var multipart: MultipartPart<Body> { get throws }
}

/// A type that can be converted from a `MultipartPart`.
public protocol MultipartPartDecodable {
    init(multipart: MultipartPart<some MultipartPartBodyElement>) throws
}

/// A type that can be converted to and from a `MultipartPart`.
public protocol MultipartPartConvertible<Body>: MultipartPartEncodable, MultipartPartDecodable where Body == Self.Body {}

extension MultipartPart: MultipartPartConvertible {
    public var multipart: MultipartPart<Body> {
        self
    }

    public init(multipart: MultipartPart<some MultipartPartBodyElement>) {
        self = .init(headerFields: multipart.headerFields, body: .init(multipart.body))
    }
}
