import HTTPTypes

public struct MultipartPart<Body: Collection<UInt8>>: Equatable, Sendable where Body: Sendable & Equatable {
    public let headerFields: HTTPFields
    public var body: Body
    
    public init(headerFields: HTTPFields, body: Body) {
        self.headerFields = headerFields
        self.body = body
    }
}
