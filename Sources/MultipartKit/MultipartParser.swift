import struct NIO.ByteBufferAllocator

/// Parses multipart-encoded `Data` into `MultipartPart`s. Multipart encoding is a widely-used format for encoding
/// web-form data that includes rich content like files. It allows for arbitrary data to be encoded
/// in each part thanks to a unique delimiter "boundary" that is defined separately. This
/// boundary is guaranteed by the client to not appear anywhere in the data.
///
/// `multipart/form-data` is a special case of `multipart` encoding where each part contains a `Content-Disposition`
/// header and name. This is used by the `FormDataEncoder` and `FormDataDecoder` to convert `Codable` types to/from
/// multipart data.
///
/// See [Wikipedia](https://en.wikipedia.org/wiki/MIME#Multipart_messages) for more information.
///
/// Seealso `form-urlencoded` encoding where delimiter boundaries are not required.
public final class MultipartParser {
    private enum Error: Swift.Error {
        case syntax
    }

    private enum CRLF {
        case cr, lf
    }

    private enum HeaderState {
        case preHeaders(CRLF = .cr)
        case headerName([UInt8] = [])
        case headerValue([UInt8] = [], name: [UInt8])
        case postHeaderValue([UInt8], name: [UInt8])
        case postHeaders
    }

    private enum State {
        case preamble(boundaryMatchIndex: Int = 0)
        case headers(state: HeaderState = .preHeaders())
        case body(lowerBound: Int, boundaryMatchIndex: Int = 0)
        case epilogue
    }

    public var onHeader: (String, String) -> ()
    public var onBody: (inout ByteBuffer) -> ()
    public var onPartComplete: () -> ()

    private let boundary: [UInt8]
    private let boundaryLength: Int
    private var state: State
    private var buffer: ByteBuffer!
    private var bufferForSlicing: ByteBuffer!

    /// Create a new parser
    /// - Parameter boundary: boundary separating parts. Must not be empty nor longer than 70 characters according to rfc1341 but we don't check for the latter.
    public init(boundary: String) {
        precondition(!boundary.isEmpty)

        self.onHeader = { _, _ in }
        self.onBody = { _ in }
        self.onPartComplete = { }

        self.boundary = Array("\r\n--\(boundary)".utf8)
        self.boundaryLength = self.boundary.count
        self.state = .preamble(boundaryMatchIndex: 0)
    }

    public func execute(_ string: String) throws {
        try execute(ByteBuffer(string: string))
    }

    public func execute(_ bytes: [UInt8]) throws {
        try execute(ByteBuffer(bytes: bytes))
    }

    public func execute(_ buffer: ByteBuffer) throws {
        self.buffer = buffer
        defer { self.buffer = nil }

        self.bufferForSlicing = buffer
        defer { self.bufferForSlicing = nil }

        try execute()
    }

    private func execute() throws {
        while buffer.readableBytes > 0 {
            switch state {
            case let .preamble(boundaryMatchIndex):
                state = parsePreamble(boundaryMatchIndex: boundaryMatchIndex)
            case let .headers(headerState):
                state = try parseHeaders(headerState: headerState)
            case let .body(lowerbound, boundaryMatchIndex):
                state = try parseBody(lowerbound, boundaryMatchIndex: boundaryMatchIndex)
            case .epilogue:
                // ignore any data in epilogue
                return
            }
        }
    }

    private func readByte() -> UInt8? { buffer.readInteger() }

    private func parsePreamble(boundaryMatchIndex: Int) -> State {
        var boundaryMatchIndex = boundaryMatchIndex

        while boundaryMatchIndex < boundaryLength, let byte = readByte() {
            // (continues to) match boundary: move on to next index

            if boundaryMatchIndex == 0, byte == boundary[2] {
                boundaryMatchIndex = 3
            } else if byte == boundary[boundaryMatchIndex] {
                boundaryMatchIndex = boundaryMatchIndex + 1
            // stopped matching boundary but matches with start of boundary: restart at 1
            } else if boundaryMatchIndex > 0, byte == boundary[0] {
                boundaryMatchIndex = 1
            // no match at either current position or start of boundary: restart at 0
            } else {
                boundaryMatchIndex = 0
            }
        }

        if boundaryMatchIndex >= boundaryLength {
            return .headers()
        } else {
            return .preamble(boundaryMatchIndex: boundaryMatchIndex)
        }
    }

    private func parseCRLF(_ crlf: CRLF) throws -> CRLF? {
        var crlf = crlf

        while let byte = readByte() {
            switch (crlf, byte) {
            case (.cr, .cr):
                crlf = .lf
            case (.lf, .lf):
                return nil
            default:
                throw Error.syntax
            }
        }

        return crlf
    }

    private func parseHeaders(headerState: HeaderState) throws -> State {
        var headerState = headerState

        while buffer.readableBytes > 0 {
            switch headerState {
            case let .preHeaders(crlf):
                headerState = try parseCRLF(crlf).map(HeaderState.preHeaders) ?? .headerName()
            case let .headerName(name):
                headerState = try parseHeaderName(name: name)
            case let .headerValue(value, name):
                headerState = try parseHeaderValue(value, name: name)
            case let .postHeaderValue(value, name):
                guard readByte() == .lf else {
                    throw Error.syntax
                }
                onHeader(String(bytes: name, encoding: .ascii) ?? "", String(bytes: value, encoding: .ascii) ?? "")
                headerState = .headerName([])
            case .postHeaders:
                guard readByte() == .lf else {
                    throw Error.syntax
                }
                return .body(lowerBound: buffer.readableBytes > 0 ? buffer.readerIndex : 0)
            }
        }

        return .headers(state: headerState)
    }

    private func parseHeaderName(name: [UInt8]) throws -> HeaderState {
        var name = name

        while let byte = readByte() {
            switch byte {
            case .colon:
                return .headerValue(name: name)
            case .cr where name.isEmpty:
                return .postHeaders
            // TODO: deal with invalid characters
            default:
                name.append(byte)
            }
        }

        return .headerName(name)
    }

    private func parseHeaderValue(_ value: [UInt8], name: [UInt8]) throws -> HeaderState {
        var value = value

        while let byte = readByte() {
            switch byte {
            case .cr:
                return .postHeaderValue(value, name: name)
            case .space, .tab:
                if value.isEmpty {
                    continue
                }
                fallthrough
            // TODO: deal with invalid characters
            default:
                value.append(byte)
            }
        }

        return .headerValue(value, name: name)
    }

    private func parseBody(_ lowerBound: Int, boundaryMatchIndex: Int) throws -> State {
        var lowerBound = lowerBound
        var boundaryMatchIndex = boundaryMatchIndex

        func sendBody(shorten: Bool = false) {
            guard boundaryMatchIndex == 0 else {
                return
            }
            let length = buffer.readerIndex - lowerBound - (shorten ? 1 : 0)
            if length > 0, var slice = bufferForSlicing.getSlice(at: lowerBound, length: length) {
                onBody(&slice)
            }
        }
        defer {
            sendBody()
        }

        while true {
            guard let byte = readByte() else {
                return .body(lowerBound: 0, boundaryMatchIndex: boundaryMatchIndex)
            }

            guard boundaryMatchIndex < boundaryLength else {
                lowerBound = buffer.readerIndex
                onPartComplete()
                switch byte {
                case .cr:
                    return .headers(state: .preHeaders(.lf))
                case .hyphen:
                    return .epilogue
                default:
                    throw Error.syntax
                }
            }

            switch (boundaryMatchIndex, byte == boundary[boundaryMatchIndex]) {
            case (0, true):
                sendBody(shorten: true)
                lowerBound = buffer.readerIndex
                fallthrough
            case (_, true):
                boundaryMatchIndex += 1
            case (1..., false):
                var a = ByteBuffer(bytes: boundary[0..<boundaryMatchIndex])
                onBody(&a)
                lowerBound = buffer.readerIndex - 1
                fallthrough
            default:
                boundaryMatchIndex = 0
            }
        }
    }
}

private extension UInt8 {
    static let colon: UInt8 = 58
    static let lf: UInt8 = 10
    static let cr: UInt8 = 13
    static let hyphen: UInt8 = 45
    static let space: UInt8 = 9
    static let tab: UInt8 = 32
}
