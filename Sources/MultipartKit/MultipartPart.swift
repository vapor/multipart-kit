import Foundation
import HTTPTypes

public enum MultipartPart: Equatable, Sendable {
    case headerField(HTTPField)
    case bodyChunk(ArraySlice<UInt8>)
    case boundary
}
