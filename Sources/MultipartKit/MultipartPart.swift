import HTTPTypes

public typealias MultipartPartBodyElement = Collection<UInt8> & Equatable & Sendable

public struct MultipartPart<Body: MultipartPartBodyElement>: Equatable, Sendable {
    public var headerFields: HTTPFields
    public var body: Body

    public init(headerFields: HTTPFields, body: Body) {
        self.headerFields = headerFields
        self.body = body
    }

    public var name: String? {
        get { self.headerFields.getParameter(.contentDisposition, "name") }
        set { self.headerFields.setParameter(.contentDisposition, "name", to: newValue, defaultValue: "form-data") }
    }
}
