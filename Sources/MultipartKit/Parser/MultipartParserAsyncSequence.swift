import HTTPTypes

/// A sequence that parses a stream of multipart data into parts asynchronously.
///
/// This sequence is designed to be used with `AsyncStream` to parse a stream of data asynchronously.
/// Different to the ``StreamingMultipartParserAsyncSequence``, this sequence will collate the body
/// chunks into one section rather than yielding them individually.
///
/// Each part's body therefore arrives as a single `.bodyChunk` section, which is convenient when
/// parts are small enough to hold in memory. For large parts, such as file uploads, prefer
/// ``StreamingMultipartParserAsyncSequence``, which never holds a whole body at once.
///
/// ```swift
/// let sequence = MultipartParserAsyncSequence(boundary: "boundary123", buffer: stream)
///
/// for try await section in sequence {
///     switch section {
///     case .headerFields(let fields): print(fields)
///     case .bodyChunk(let body): print(String(decoding: body, as: UTF8.self))
///     case .boundary: break
///     }
/// }
/// ```
public struct MultipartParserAsyncSequence<BackingSequence: AsyncSequence>: AsyncSequence
where BackingSequence.Element: MultipartPartBodyElement {
    let streamingSequence: StreamingMultipartParserAsyncSequence<BackingSequence>

    /// Creates a sequence that parses the multipart message carried by `buffer`.
    ///
    /// - Parameters:
    ///   - boundary: The boundary separating the parts of the message, without its leading
    ///     hyphens. For a message delimited by `--abc123`, pass `abc123`.
    ///   - buffer: An asynchronous sequence of chunks making up the multipart message. Chunks
    ///     may be split at any point; they need not line up with the message's structure.
    public init(boundary: String, buffer: BackingSequence) {
        self.streamingSequence = .init(boundary: boundary, buffer: buffer)
    }

    /// An iterator over the sections of a multipart message, with each part's body collated.
    public struct AsyncIterator: AsyncIteratorProtocol {
        var streamingIterator: StreamingMultipartParserAsyncSequence<BackingSequence>.AsyncIterator

        /// Advances to the next section of the message.
        ///
        /// - Throws: ``MultipartParserError`` if the message is malformed, if it ends part-way
        ///   through a part, or if the backing sequence itself throws.
        /// - Returns: The next section, or `nil` once the message is complete.
        public mutating func next() async throws(MultipartParserError) -> MultipartSection<BackingSequence.Element>? {
            try await streamingIterator.nextCollatedPart()
        }

        /// Advances to the next section of the message, inheriting the caller's actor isolation.
        ///
        /// - Parameter isolation: The actor to remain isolated to, defaulting to the caller's isolation.
        /// - Throws: ``MultipartParserError`` if the message is malformed, if it ends part-way
        ///   through a part, or if the backing sequence itself throws.
        /// - Returns: The next section, or `nil` once the message is complete.
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public mutating func next(isolation actor: isolated (any Actor)? = #isolation) async throws(MultipartParserError)
            -> MultipartSection<BackingSequence.Element>?
        {
            try await streamingIterator.nextCollatedPart(isolation: actor)
        }
    }

    /// Creates an iterator over the sections of the message.
    public func makeAsyncIterator() -> AsyncIterator {
        .init(streamingIterator: self.streamingSequence.makeAsyncIterator())
    }
}
