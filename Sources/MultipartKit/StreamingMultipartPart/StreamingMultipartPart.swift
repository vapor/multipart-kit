public import HTTPTypes

public struct StreamingMultipartPart<Body: AsyncSequence & Sendable>: Sendable
where Body.Element: MultipartPartBodyElement {
    public let headerFields: HTTPFields
    public let body: Body

    public init(headerFields: HTTPFields, body: Body) {
        self.headerFields = headerFields
        self.body = body
    }
}

@nonexhaustive public enum StreamingMultipartPartError: Error {
    case nextPartRequestedWhileStreamingPreviousBody
}
