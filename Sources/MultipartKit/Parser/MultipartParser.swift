import HTTPTypes

/// Parses any kind of multipart encoded data into ``MultipartSection``s.
///
/// Use ``parse(_:)`` when the whole message is already in memory. To parse a message as it
/// arrives, wrap the incoming chunks in a ``StreamingMultipartParserAsyncSequence`` or a
/// ``MultipartParserAsyncSequence`` instead.
public struct MultipartParser: Sendable {
    private(set) var stateMachine: StateMachine
    private(set) var buffer: ArraySlice<UInt8>

    /// Creates a new parser for messages separated by the given boundary.
    ///
    /// - Parameter boundary: The boundary separating the parts of the message, without its
    ///   leading hyphens. For a message delimited by `--abc123`, pass `abc123`.
    public init(boundary: String) {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(4 + boundary.utf8.count)
        bytes.append(contentsOf: Array.crlf)
        bytes.append(contentsOf: Array.twoHyphens)
        bytes.append(contentsOf: boundary.utf8)
        self.stateMachine = .init(state: .initial, crlfWithBoundary: bytes)
        self.buffer = .init()
    }

    enum ReadResult {
        case finished
        case success(reading: MultipartSection<ArraySlice<UInt8>>? = nil)
        case error(MultipartParserError)
        case needMoreData
    }

    mutating func append(buffer: ArraySlice<UInt8>) {
        if self.buffer.isEmpty {
            self.buffer = buffer
        } else {
            self.buffer.append(contentsOf: buffer)
        }
    }

    private func section(from section: MultipartParser.StateMachine.Section) -> MultipartSection<ArraySlice<UInt8>> {
        switch section {
        case .boundary(let end):
            .boundary(end: end)

        case .bodyChunk(let range):
            .bodyChunk(buffer[(buffer.startIndex + range.lowerBound)..<(buffer.startIndex + range.upperBound)])

        case .headerFields(let fields):
            .headerFields(fields)
        }
    }

    mutating func read() -> ReadResult {
        // TODO: Drop this when we drop 6.3
        let bytes = self.buffer

        switch stateMachine.read(bytes.span) {
        case .emit(let smSection, let consumed):
            let section = self.section(from: smSection)
            buffer = buffer.dropFirst(consumed)
            return .success(reading: section)

        case .feedMoreData(let consumed):
            buffer = buffer.dropFirst(consumed)
            return .needMoreData

        case .fail(let error):
            return .error(error)

        case .finished:
            return .finished
        }
    }
}
