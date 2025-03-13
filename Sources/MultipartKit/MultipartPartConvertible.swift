/// A protocol to provide custom behaviors for parsing and serializing types from and to multipart data.
public protocol MultipartPartConvertible<Body> {
    associatedtype Body: MultipartPartBodyElement

    var multipart: MultipartPart<Body>? { get }
    init?(multipart: MultipartPart<some MultipartPartBodyElement>)
}

extension MultipartPart: MultipartPartConvertible {
    public var multipart: MultipartPart<Body>? {
        self
    }

    public init?(multipart: MultipartPart<some MultipartPartBodyElement>) {
        self = .init(headerFields: multipart.headerFields, body: .init(multipart.body))
    }
}
