public import HTTPTypes

/// A type that can be converted to a ``MultipartPart``.
///
/// Conform a type to this protocol to control how it is written into a multipart message,
/// for instance to attach a `Content-Type` header alongside its bytes.
public protocol MultipartPartEncodable {
    var headerFields: HTTPFields { get throws }

    var body: RawSpan { @_lifetime(borrow self) get }
}

/// A type that can be converted from a ``MultipartPart``.
///
/// Conform a type to this protocol to control how it is read out of a multipart message.
public protocol MultipartPartDecodable {
    /// Creates an instance from a ``MultipartPart``.
    ///
    /// - Parameter multipart: The part to convert.
    /// - Throws: If the part does not hold a valid representation of this type.
    // init(multipart: MultipartPart<Body>) throws
    init(headerFields: HTTPFields, body: RawSpan) throws
}

/// A type that can be converted to and from a ``MultipartPart``.
public typealias MultipartPartConvertible = MultipartPartEncodable & MultipartPartDecodable
