/// A type that can be converted to a ``MultipartPart``.
///
/// Conform a type to this protocol to control how it is written into a multipart message,
/// for instance to attach a `Content-Type` header alongside its bytes.
public protocol MultipartPartEncodable<Body> {
    /// The body type of the part this value converts to.
    associatedtype Body: MultipartPartBodyElement

    /// This value represented as a ``MultipartPart``.
    ///
    /// - Throws: If the value cannot be represented as a part.
    var multipart: MultipartPart<Body> { get throws }
}

/// A type that can be converted from a ``MultipartPart``.
///
/// Conform a type to this protocol to control how it is read out of a multipart message.
public protocol MultipartPartDecodable<Body> {
    /// The body type of the part this value converts from.
    associatedtype Body: MultipartPartBodyElement

    /// Creates an instance from a ``MultipartPart``.
    ///
    /// - Parameter multipart: The part to convert.
    /// - Throws: If the part does not hold a valid representation of this type.
    init(multipart: MultipartPart<Body>) throws
}

/// A type that can be converted to and from a ``MultipartPart``.
public typealias MultipartPartConvertible = MultipartPartEncodable & MultipartPartDecodable

extension MultipartPart: MultipartPartConvertible {
    /// This part, unchanged.
    public var multipart: MultipartPart<Body> {
        self
    }

    /// Creates a part from another part, converting its body to this part's body type.
    ///
    /// - Parameter multipart: The part to copy the header fields and body from.
    public init(multipart: MultipartPart<some MultipartPartBodyElement>) {
        self = .init(headerFields: multipart.headerFields, body: .init(multipart.body))
    }
}
