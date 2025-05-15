/// A protocol to provide custom behaviors for parsing and serializing types from and to multipart data.

public protocol MultipartPartEncodable<Body> {
    associatedtype Body: MultipartPartBodyElement

    var multipart: MultipartPart<Body> { get throws }
}

public protocol MultipartPartDecodable {
    init(multipart: MultipartPart<some MultipartPartBodyElement>) throws
}

public protocol MultipartPartConvertible<Body>: MultipartPartEncodable, MultipartPartDecodable where Body == Self.Body {}

extension MultipartPart: MultipartPartConvertible {
    public var multipart: MultipartPart<Body> {
        self
    }

    public init(multipart: MultipartPart<some MultipartPartBodyElement>) {
        self = .init(headerFields: multipart.headerFields, body: .init(multipart.body))
    }
}
