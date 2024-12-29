package enum MultipartParserError: Swift.Error, Equatable {
    case invalidBoundary
    case invalidHeader(reason: String)
    case invalidBody(reason: String)
}
