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

// TODO: Make this @nonexhaustive when we drop 6.1
public struct StreamingMultipartPartError: Error, Equatable {
    enum Backing {
        case nextPartRequestedWhileStreamingPreviousBody
    }

    let backing: Backing

    init(_ backing: Backing) {
        self.backing = backing
    }

    public static let nextPartRequestedWhileStreamingPreviousBody = Self(.nextPartRequestedWhileStreamingPreviousBody)
}
