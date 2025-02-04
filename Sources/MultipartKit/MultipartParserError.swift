/// Technical parsing error, such as malformed data or invalid characters.
/// This is mainly used by ``MultipartParser``.
/// Protocol for `MultipartParserError`, allowing extensibility without breaking the API.
public protocol MultipartParserError: Swift.Error, Equatable {}

public struct InvalidBoundaryError: MultipartParserError {
    public init() {}
}

public struct InvalidHeaderError: MultipartParserError {
    public let reason: String
    
    public init(reason: String) {
        self.reason = reason
    }
}

public struct InvalidBodyError: MultipartParserError {
    public let reason: String
    
    public init(reason: String) {
        self.reason = reason
    }
}

public enum MultipartParserErrorType {
    case invalidBoundary
    case invalidHeader(String)
    case invalidBody(String)
}

public struct MultipartParserErrorWrapper: MultipartParserError {
    public let type: MultipartParserErrorType
    
    public init(type: MultipartParserErrorType) {
        self.type = type
    }
}
