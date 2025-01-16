import MultipartKit

extension MultipartSection: Equatable where Body: Equatable {
    public static func == (lhs: MultipartKit.MultipartSection<Body>, rhs: MultipartKit.MultipartSection<Body>) -> Bool {
        switch (lhs, rhs) {
        case let (.headerFields(lhsFields), .headerFields(rhsFields)):
            lhsFields == rhsFields
        case let (.bodyChunk(lhsChunk), .bodyChunk(rhsChunk)):
            lhsChunk == rhsChunk
        case (.boundary, .boundary):
            true
        default:
            false
        }
    }
}
