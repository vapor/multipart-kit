import HTTPTypes

public typealias MultipartPartBodyElement = Collection<UInt8> & Sendable

/// Represents a single part of a multipart-encoded message.
public struct MultipartPart<Body: MultipartPartBodyElement>: Sendable {
    /// The header fields for this part.
    public var headerFields: HTTPFields

    /// The body of this part.
    public var body: Body

    /// Creates a new ``MultipartPart``.
    ///
    ///     let part = MultipartPart(headerFields: [.contentDisposition: "form-data"], body: Array("Hello, world!".utf8))
    ///
    /// - Parameters:
    ///  - headerFields: The header fields for this part.
    ///  - body: The body of this part.
    public init(headerFields: HTTPFields, body: Body) {
        self.headerFields = headerFields
        self.body = body
    }

    /// Gets or sets the `name` attribute of the part's `"Content-Disposition"` header.
    public var name: String? {
        get { self.headerFields.getParameter(.contentDisposition, "name") }
        set { self.headerFields.setParameter(.contentDisposition, "name", to: newValue, defaultValue: "form-data") }
    }
}
