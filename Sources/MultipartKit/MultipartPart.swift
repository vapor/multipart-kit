import Foundation
import HTTPTypes
import NIOCore
import NIOHTTP1

public enum MultipartPart: Equatable, Sendable {
    case headerField(HTTPField)
    case bodyChunk(ByteBuffer)
    case boundary
}
