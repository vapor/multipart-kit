/// Technical parsing error, such as malformed data or invalid characters.
/// This is mainly used by ``MultipartParser``.
public struct MultipartParserError: Swift.Error, Equatable, Sendable, CustomStringConvertible {
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

    public var reason: String? {
        switch base {
        case .invalidHeader(let reason), .invalidBody(let reason):
            return reason
        case .invalidBoundary:
            return nil
        }
    }


    public var description: String {
        switch base {
        case .invalidBoundary:
            return "MultipartParserError: Invalid boundary."
        case .invalidHeader(let reason):
            return "MultipartParserError: Invalid header. Reason: \(reason)"
        case .invalidBody(let reason):
            return "MultipartParserError: Invalid body. Reason: \(reason)"
        }
    }
}

