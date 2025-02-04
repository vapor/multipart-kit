/// Technical parsing error, such as malformed data or invalid characters.
/// This is mainly used by ``MultipartParser``.
public struct MultipartParserError: Swift.Error, Equatable {
    public let reason: Reason

    private init(reason: Reason) {
        self.reason = reason
    }

    public enum Reason: Equatable {
        case invalidBoundary
        case invalidHeader(reason: String)
        case invalidBody(reason: String)
    }

    public static let invalidBoundary = MultipartParserError(reason: .invalidBoundary)
    
    public static func invalidHeader(reason: String) -> MultipartParserError {
        return MultipartParserError(reason: .invalidHeader(reason: reason))
    }
    public static func invalidBody(_ reason: String) -> MultipartParserError {
        return MultipartParserError(reason: .invalidBody(reason: reason))
    }
}
