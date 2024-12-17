import HTTPTypes

public enum MultipartSection<Body: MultipartPartBodyElement>: Equatable, Sendable {
    case headerFields(HTTPFields)
    case bodyChunk(Body)
    case boundary(end: Bool)
}
