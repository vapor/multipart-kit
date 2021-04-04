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
    private var sliceBuffer: ByteBuffer!

    /// Creates a new `MultipartParser`.
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

        self.sliceBuffer = buffer
        defer { self.sliceBuffer = nil }

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

            // allow skipping the initial CRLF
            if boundaryMatchIndex == 0, byte == boundary[2] {
                boundaryMatchIndex = 3
            // (continues to) match boundary: move on to next index
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
            case .colon where !name.isEmpty:
                return .headerValue(name: name)
            case .cr where name.isEmpty:
                return .postHeaders
            case _ where byte.isValidHeaderCharacter:
                name.append(byte)
            default:
                throw Error.syntax
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
            default:
                value.append(byte)
            }
        }

        return .headerValue(value, name: name)
    }

    private func parseBody(_ lowerBound: Int, boundaryMatchIndex: Int) throws -> State {
        var lowerBound = lowerBound
        var boundaryMatchIndex = boundaryMatchIndex

        func sendBody() {
            // don't send the body if we're (potentially) inside the boundary
            guard boundaryMatchIndex == 0 else {
                return
            }

            if var slice = sliceBuffer.getSlice(at: lowerBound, length: buffer.readerIndex - lowerBound), slice.readableBytes > 0 {
                onBody(&slice)
            }
        }

        while true {
            guard let byte = readByte() else {
                sendBody()
                return .body(lowerBound: 0, boundaryMatchIndex: boundaryMatchIndex)
            }

            guard boundaryMatchIndex < boundaryLength else {
                lowerBound = buffer.readerIndex
                sendBody()
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
                if var slice = sliceBuffer.getSlice(at: lowerBound, length: buffer.readerIndex - lowerBound - 1) {
                    onBody(&slice)
                }
                lowerBound = buffer.readerIndex
                fallthrough
            case (_, true):
                boundaryMatchIndex += 1
            case (1..., false):
                var boundaryBuffer = ByteBuffer(bytes: boundary[0..<boundaryMatchIndex])
                onBody(&boundaryBuffer)
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

    /*
        * field-name    = token
        * token         = 1*<any CHAR except CTLs or tspecials>
        * CTL           = <any US-ASCII control character (octets 0 - 31) and DEL (127)>
        * tspecials     = "(" | ")" | "<" | ">" | "@"
        *               | "," | ";" | ":" | "\" | DQUOTE
        *               | "/" | "[" | "]" | "?" | "="
        *               | "{" | "}" | SP | HT
        * DQUOTE        = <US-ASCII double-quote mark (34)>
        * SP            = <US-ASCII SP, space (32)>
        * HT            = <US-ASCII HT, horizontal-tab (9)>
     */
    private static let validHeaderCharacters: [Bool] = [
        //  0 nul   1 soh   2 stx   3 etx   4 eot   5 enq   6 ack   7 bel
            false,  false,  false,  false,  false,  false,  false,  false,
        //  8 bs    9 ht    10 nl   11 vt   12 np   13 cr   14 so   15 si
            false,  false,  false,  false,  false,  false,  false,  false,
        //  16 dle  17 dc1  18 dc2  19 dc3  20 dc4  21 nak  22 syn  23 etb
            false,  false,  false,  false,  false,  false,  false,  false,
        //  24 can  25 em   26 sub  27 esc  28 fs   29 gs   30 rs   31 us
            false,  false,  false,  false,  false,  false,  false,  false,
        //  32 sp   33 !    34 "    35 #    36 $    37 %    38 &    39
            false,  true,   false,  true,   true,   true,   true,   true,
        //  40 (    41 )    42 *    43 +    44 ,    45 -    46 .    47
            false,  false,  true,   true,   false,  true,   true,   false,
        //  48 0    49 1    50 2    51 3    52 4    53 5    54 6    55 7
            true,   true,   true,   true,   true,   true,   true,   true,
        //  56 8    57 9    58 :    59 ;    60 <    61 =    62 >    63
            true,   true,   false,  false,  false,  false,  false,  false,
        //  64 @    65 A    66 B    67 C    68 D    69 E    70 F    71 G
            false,  true,   true,   true,   true,   true,   true,   true,
        //  72 H    73 I    74 J    75 K    76 L    77 M    78 N    79 O
            true,   true,   true,   true,   true,   true,   true,   true,
        //  80 P    81 Q    82 R    83 S    84 T    85 U    86 V    87 W
            true,   true,   true,   true,   true,   true,   true,   true,
        //  88 X    89 Y    90 Z    91 [    92 \    93 ]    94 ^    95 _
            true,   true,   true,    false, false,  false,  true,   true,
        //  96 `    97 a    98 b    99 c    100 d   101 e   102 f   103 g
            true,   true,   true,   true,   true,   true,   true,   true,
        //  104 h   105 i   106 j   107 k   108 l   109 m   110 n   111 o
            true,   true,   true,   true,   true,   true,   true,   true,
        //  112 p   113 q   114 r   115 s   116 t   117 u   118 v   119 w
            true,   true,   true,   true,   true,   true,   true,   true,
        //  120 x   121 y   122 z   123 {   124 |   125 }   126 ~   127 del
            true,   true,   true,   false,  true,   false,  true,   false
    ]

    var isValidHeaderCharacter: Bool {
        Self.validHeaderCharacters[Int(self)]
    }
}
