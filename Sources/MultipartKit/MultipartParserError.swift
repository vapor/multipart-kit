/// Technical parsing error, such as malformed data or invalid characters.
/// This is mainly used by ``MultipartParser``.
public struct MultipartParserError: Swift.Error, Equatable {

    enum Base: Equatable {
        case invalidBoundary
        case invalidHeader(reason: String)
        case invalidBody(reason: String)
    }

    let base: Base

    private init(base: Base) {
        self.base = base
    }

    public static let invalidBoundary = MultipartParserError(base: .invalidBoundary)

    public static func invalidHeader(reason: String) -> MultipartParserError {
        return MultipartParserError(base: .invalidHeader(reason: reason))
    }
    public static func invalidBody(reason: String) -> MultipartParserError {
        return MultipartParserError(base: .invalidBody(reason: reason))    
    }
}
