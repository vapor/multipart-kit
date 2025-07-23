import HTTPTypes

/// A sequence that parses a stream of multipart data into sections asynchronously.
///
/// This sequence is designed to be used with `AsyncStream` to parse a stream of data asynchronously.
/// The sequence will yield ``MultipartSection`` values as they are parsed from the stream.
///
/// ```swift
/// let boundary = "boundary123"
/// var message = ArraySlice(...)
/// let stream = AsyncStream { continuation in
/// var offset = message.startIndex
///     while offset < message.endIndex {
///         let endIndex = min(message.endIndex, message.index(offset, offsetBy: 16))
///         continuation.yield(message[offset..<endIndex])
///         offset = endIndex
///     }
///     continuation.finish()
/// }
/// let sequence = StreamingMultipartParserAsyncSequence(boundary: boundary, buffer: stream)
/// for try await part in sequence {
///     switch part {
///     case .bodyChunk(let chunk): ...
///     case .headerFields(let field): ...
///     case .boundary: break
/// }
/// ```
///
public struct StreamingMultipartParserAsyncSequence<BackingSequence: AsyncSequence>: AsyncSequence
where BackingSequence.Element: MultipartPartBodyElement {
    let parser: MultipartParser<BackingSequence.Element>
    let buffer: BackingSequence

    public init(boundary: String, buffer: BackingSequence) {
        self.parser = .init(boundary: boundary)
        self.buffer = buffer
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = MultipartSection<BackingSequence.Element>

        var parser: MultipartParser<BackingSequence.Element>
        var iterator: BackingSequence.AsyncIterator

        var pendingBodyChunk: BackingSequence.Element?

        var currentCollatedBody = BackingSequence.Element()
        
        /// Maximum size for collated body to prevent unbounded memory growth
        /// Default is 64MB which should be sufficient for most use cases
        private let maxCollatedBodySize: Int
        private var currentCollatedBodySize: Int = 0
        
        init(parser: MultipartParser<BackingSequence.Element>, iterator: BackingSequence.AsyncIterator, maxCollatedBodySize: Int = 64 * 1024 * 1024) {
            self.parser = parser
            self.iterator = iterator
            self.maxCollatedBodySize = maxCollatedBodySize
        }

        public mutating func next() async throws(MultipartParserError) -> MultipartSection<BackingSequence.Element>? {
            if let pendingBodyChunk {
                defer { self.pendingBodyChunk = nil }
                return .bodyChunk(pendingBodyChunk)
            }

            var headerFields = HTTPFields()

            while true {
                switch parser.read() {
                case .success(let optionalPart):
                    switch optionalPart {
                    case .none: continue
                    case .some(let part):
                        switch part {
                        case .headerFields(let fields):
                            headerFields.append(contentsOf: fields)
                            continue
                        case .bodyChunk(let chunk):
                            if !headerFields.isEmpty {
                                pendingBodyChunk = chunk
                                let returningFields = headerFields
                                headerFields = .init()
                                return .headerFields(returningFields)
                            }
                            return .bodyChunk(chunk)
                        case .boundary:
                            return part
                        }
                    }
                case .needMoreData:
                    let next: BackingSequence.Element?
                    do {
                        next = try await iterator.next()
                    } catch {
                        throw MultipartParserError.backingSequenceError(reason: "\(error)")
                    }
                    if let next {
                        parser.append(buffer: next)
                    } else {
                        switch parser.state {
                        case .initial, .finished:
                            return nil
                        case .parsing:
                            throw MultipartParserError.unexpectedEndOfFile
                        }
                    }
                case .error(let error):
                    throw error
                case .finished:
                    return nil
                }
            }
        }

        public mutating func nextCollatedPart() async throws(MultipartParserError) -> MultipartSection<BackingSequence.Element>? {
            var headerFields = HTTPFields()

            while let part = try await self.next() {
                switch part {
                case .headerFields(let fields):
                    headerFields.append(contentsOf: fields)
                case .bodyChunk(let chunk):
                    // Check size limits before appending to prevent unbounded memory growth
                    let chunkSize = chunk.count
                    if currentCollatedBodySize + chunkSize > maxCollatedBodySize {
                        throw MultipartParserError.invalidBody(
                            reason: "Collated body size (\(currentCollatedBodySize + chunkSize) bytes) exceeds maximum allowed size (\(maxCollatedBodySize) bytes)"
                        )
                    }
                    
                    self.currentCollatedBody.append(contentsOf: chunk)
                    self.currentCollatedBodySize += chunkSize
                    
                    if !headerFields.isEmpty {
                        defer { headerFields = .init() }
                        return .headerFields(headerFields)
                    }
                case .boundary:
                    if !currentCollatedBody.isEmpty {
                        defer { 
                            currentCollatedBody = .init()
                            currentCollatedBodySize = 0
                        }
                        return .bodyChunk(currentCollatedBody)
                    }
                }
            }
            return nil
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        .init(parser: parser, iterator: buffer.makeAsyncIterator())
    }
}
