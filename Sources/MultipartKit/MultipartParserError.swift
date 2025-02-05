/// Technical parsing error, such as malformed data or invalid characters.
/// This is mainly used by ``MultipartParser``.
public struct MultipartParserError: Swift.Error, Equatable, Sendable {
    enum Base: Equatable {
        case invalidBoundary
        case invalidHeader(reason: String)
        case invalidBody(reason: String)
    }

    let base: Base

    private init(_ base: Base) {
        self.base = base
    }

    public static let invalidBoundary = MultipartParserError(.invalidBoundary)

    public static func invalidHeader(reason: String) -> MultipartParserError {
        .init(.invalidHeader(reason: reason))
    }
    
    public static func invalidBody(reason: String) -> MultipartParserError {
        .init(.invalidBody(reason: reason))    
    }
}
