import HTTPTypes

/// A sequence that parses a stream of multipart data into parts asynchronously.
///
/// This sequence is designed to be used with `AsyncStream` to parse a stream of data asynchronously.
/// Different to the ``StreamingMultipartParserAsyncSequence``, this sequence will collate the body
/// chunks into one section rather than yielding them individually.
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
    let streamingSequence: StreamingMultipartParserAsyncSequence<BackingSequence>

    public init(boundary: String, buffer: BackingSequence) {
        self.streamingSequence = .init(boundary: boundary, buffer: buffer)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var streamingIterator: StreamingMultipartParserAsyncSequence<BackingSequence>.AsyncIterator
        var currentCollatedBody: BackingSequence.Element = .init()
        
        public mutating func next() async throws -> MultipartSection<BackingSequence.Element>? {
            var headerFields = HTTPFields()

            while let part = try await streamingIterator.next() {
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

    public func makeAsyncIterator() -> AsyncIterator {
        .init(streamingIterator: self.streamingSequence.makeAsyncIterator())
    }
}
