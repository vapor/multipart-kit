import MultipartKit

extension MultipartSection: Equatable where Body: Equatable {
    public static func == (lhs: MultipartKit.MultipartSection<Body>, rhs: MultipartKit.MultipartSection<Body>) -> Bool {
        switch (lhs, rhs) {
        case (.headerFields(let lhsFields), .headerFields(let rhsFields)):
            lhsFields == rhsFields
        case (.bodyChunk(let lhsChunk), .bodyChunk(let rhsChunk)):
            lhsChunk == rhsChunk
        case (.boundary, .boundary):
            true
        default:
            false
        }
    }
}
