import HTTPTypes

/// A sequence that parses a stream of multipart data into sections asynchronously.
///
/// This sequence is designed to be used with `AsyncStream` to parse a stream of data asynchronously.
/// The sequence will yield ``MultipartSection`` values as they are parsed from the stream.
///
///     let boundary = "boundary123"
///     var message = ArraySlice(...)
///     let stream = AsyncStream { continuation in
///     var offset = message.startIndex
///         while offset < message.endIndex {
///             let endIndex = min(message.endIndex, message.index(offset, offsetBy: 16))
///             continuation.yield(message[offset..<endIndex])
///             offset = endIndex
///         }
///         continuation.finish()
///     }
///     let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: stream)
///     for try await part in sequence {
///         switch part {
///         case .bodyChunk(let chunk): ...
///         case .headerFields(let field): ...
///         case .boundary: break
///     }
///
public struct MultipartParserAsyncSequence<BackingSequence: AsyncSequence>: AsyncSequence
where BackingSequence.Element: MultipartPartBodyElement & RangeReplaceableCollection {
    private let parser: MultipartParser<BackingSequence.Element>
    private let buffer: BackingSequence

    public init(boundary: String, buffer: BackingSequence) {
        self.parser = .init(boundary: boundary)
        self.buffer = buffer
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(parser: parser, iterator: buffer.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = MultipartSection<BackingSequence.Element>

        private var parser: MultipartParser<BackingSequence.Element>
        private var iterator: BackingSequence.AsyncIterator

        private var currentCollatedBody: BackingSequence.Element

        init(parser: MultipartParser<BackingSequence.Element>, iterator: BackingSequence.AsyncIterator) {
            self.parser = parser
            self.iterator = iterator
            self.currentCollatedBody = .init()
        }

        public mutating func next() async throws -> MultipartSection<BackingSequence.Element>? {
            while true {
                switch parser.read() {
                case .success(let optionalPart):
                    switch optionalPart {
                    case .none: continue
                    case .some(let part): return part
                    }
                case .needMoreData:
                    if let next = try await iterator.next() {
                        parser.append(buffer: next)
                    } else {
                        switch parser.state {
                        case .initial, .finished:
                            return nil
                        case .parsing:
                            throw MultipartParserSequenceError.unexpectedEndOfFile
                        }
                    }
                case .error(let error):
                    throw error
                case .finished:
                    return nil
                }
            }
        }

        public mutating func nextCollatedPart() async throws -> MultipartSection<BackingSequence.Element>? {
            var headerFields = HTTPFields()

            while let part = try await next() {
                switch part {
                case .headerFields(let fields):
                    headerFields.append(contentsOf: fields)
                case .bodyChunk(let chunk):
                    self.currentCollatedBody.append(contentsOf: chunk)
                    if !headerFields.isEmpty {
                        let returningFields = headerFields
                        headerFields = .init()
                        return .headerFields(returningFields)
                    }
                case .boundary:
                    if !currentCollatedBody.isEmpty {
                        let returningBody = currentCollatedBody
                        currentCollatedBody = .init()
                        return .bodyChunk(returningBody)
                    }
                }
            }
            return nil
        }
    }
}
