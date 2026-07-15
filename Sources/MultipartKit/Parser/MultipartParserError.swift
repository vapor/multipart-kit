/// Technical parsing error, such as malformed data or invalid characters.
/// This is mainly used by ``MultipartParser``.
public struct MultipartParserError: Swift.Error, Equatable, Sendable {
    /// The kind of failure a ``MultipartParserError`` describes.
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

        /// The message did not begin with the expected boundary.
        public static let invalidBoundary = Self(.invalidBoundary)

        /// A part's header fields could not be parsed.
        public static let invalidHeader = Self(.invalidHeader)

        /// A part's body could not be parsed.
        public static let invalidBody = Self(.invalidBody)

        /// The message ended while a part was still being parsed.
        public static let unexpectedEndOfFile = Self(.unexpectedEndOfFile)

        /// The `AsyncSequence` supplying the message threw an error.
        public static let backingSequenceError = Self(.backingSequenceError)

        /// The name of this error type.
        public var description: String {
            base.rawValue
        }
    }

    private struct Backing: Equatable, Sendable {
        let errorType: ErrorType
        let reason: String?
    }

    private var backing: Backing

    /// The kind of failure this error describes.
    public var errorType: ErrorType { backing.errorType }

    /// A human-readable explanation of the failure, when one is available.
    public var reason: String? { backing.reason }

    private init(backing: Backing) {
        self.backing = backing
    }

    private init(errorType: ErrorType) {
        self.backing = .init(errorType: errorType, reason: nil)
    }

    /// The message did not begin with the expected boundary.
    public static let invalidBoundary = Self(errorType: .invalidBoundary)

    /// The message ended while a part was still being parsed.
    ///
    /// This is also thrown by ``MultipartParser/parse(_:)`` when the data handed to it is an
    /// incomplete message, since a synchronous parse has no way to ask for more data.
    public static let unexpectedEndOfFile = Self(errorType: .unexpectedEndOfFile)

    /// A part's header fields could not be parsed.
    ///
    /// - Parameter reason: An explanation of why the header is invalid.
    /// - Returns: An error instance.
    public static func invalidHeader(reason: String) -> Self {
        .init(backing: .init(errorType: .invalidHeader, reason: reason))
    }

    /// A part's body could not be parsed.
    ///
    /// - Parameter reason: An explanation of why the body is invalid.
    /// - Returns: An error instance.
    public static func invalidBody(reason: String) -> Self {
        .init(backing: .init(errorType: .invalidBody, reason: reason))
    }

    /// The `AsyncSequence` supplying the message threw an error.
    ///
    /// The underlying error is not preserved; its description is carried in `reason`.
    ///
    /// - Parameter reason: A description of the error thrown by the backing sequence.
    /// - Returns: An error instance.
    public static func backingSequenceError(reason: String) -> Self {
        .init(backing: .init(errorType: .backingSequenceError, reason: reason))
    }

    /// A description of the error, including its reason when one is available.
    public var description: String {
        var result = "MultipartParserError(errorType: \(errorType)"

        if let reason {
            result.append(", reason: \(reason)")
        }

        result.append(")")

        return result
    }
}
