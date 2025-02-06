/// Technical parsing error, such as malformed data or invalid characters.
/// This is mainly used by ``MultipartParser``.
public struct MultipartParserError: Swift.Error, Equatable, Sendable {
    public struct ErrorType: Equatable, CustomStringConvertible {
        enum Base: String, Equatable {
            case invalidBoundary
            case invalidHeader
            case invalidBody
        }

        let base: Base

        private init(_ base: Base) {
            self.base = base
        }

        public static let invalidBoundary = Self(.invalidBoundary)
        public static let invalidHeader = Self(.invalidHeader)
        public static let invalidBody = Self(.invalidBody)

        public var description: String {
            base.rawValue
        }
    }

    private struct Backing: Equatable, Sendable {
        let errorType: ErrorType
        let reason: String?
    }

    private var backing: Backing

    public var errorType: ErrorType { backing.errorType }
    public var reason: String? { backing.reason }

    private init(backing: Backing) {
        self.backing = backing
    }

    private init(errorType: ErrorType) {
        self.backing = .init(errorType: errorType, reason: nil)
    }

    public static let invalidBoundary = Self(errorType: .invalidBoundary)

    public static func invalidHeader(reason: String) -> Self {
        .init(backing: .init(errorType: .invalidHeader, reason: reason))
    }
    
    public static func invalidBody(reason: String) -> Self {
        .init(backing: .init(errorType: .invalidBody, reason: reason))
    }

    public var description: String {
        if let reason = reason {
            return "MultipartParserError(errorType: \(errorType), reason: \(reason))"
        } else {
            return "MultipartParserError(errorType: \(errorType))"
        }
    }
}


