/// Technical parsing error, such as malformed data or invalid characters.
/// This is mainly used by ``MultipartParser``.
public enum MultipartParserError: Swift.Error, Equatable {
    case invalidBoundary
    case invalidHeader(reason: String)
    case invalidBody(reason: String)
}
