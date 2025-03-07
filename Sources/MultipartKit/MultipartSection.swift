import HTTPTypes

public enum MultipartSection<Body: MultipartPartBodyElement>: Sendable, Equatable {
    case headerFields(HTTPFields)
    case bodyChunk(Body)
    case boundary(end: Bool)
}
