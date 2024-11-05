import Foundation
import HTTPTypes

public enum MultipartSection: Equatable, Sendable {
    case headerFields(HTTPFields)
    case bodyChunk(ArraySlice<UInt8>)
    case boundary(end: Bool)
}
