/// Technical parsing error, such as malformed data or invalid characters.
/// This is mainly used by ``MultipartParser``.
public struct MultipartParserError: Swift.Error, Equatable, Sendable {
    public struct ErrorType: Sendable, Equatable, CustomStringConvertible {
        enum Base: String, Equatable {
            case invalidBoundary
            case invalidHeader
            case invalidBody
            case unexpectedEndOfFile
            case backingSequenceError
        }

        let base: Base

        private init(_ base: Base) {
            self.base = base
        }

        public static let invalidBoundary = Self(.invalidBoundary)
        public static let invalidHeader = Self(.invalidHeader)
        public static let invalidBody = Self(.invalidBody)
        public static let unexpectedEndOfFile = Self(.unexpectedEndOfFile)
        public static let backingSequenceError = Self(.backingSequenceError)

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
  
    public static let unexpectedEndOfFile = Self(errorType: .unexpectedEndOfFile)

    public static func invalidHeader(reason: String) -> Self {
        .init(backing: .init(errorType: .invalidHeader, reason: reason))
    }

    public static func invalidBody(reason: String) -> Self {
        .init(backing: .init(errorType: .invalidBody, reason: reason))
    }
  
    public static func backingSequenceError(reason: String) -> Self {
        .init(backing: .init(errorType: .backingSequenceError, reason: reason))
    }

    public var description: String {
        var result = "MultipartParserError(errorType: \(errorType)"

        if let reason {
            result.append(", reason: \(reason)")
        }

        result.append(")")

        return result
    }
}
