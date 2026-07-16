import HTTPTypes

/// A sequence that parses a stream of multipart data into sections asynchronously.
///
/// This sequence is designed to be used with `AsyncStream` to parse a stream of data asynchronously.
/// The sequence will yield ``MultipartSection`` values as they are parsed from the stream.
///
/// Each body chunk is yielded as soon as it is parsed, so the body of a part is never held in
/// memory in its entirety. This makes the sequence suited to large messages such as file uploads.
/// When parts are small enough to collect whole, ``MultipartParserAsyncSequence`` is easier to use:
/// it yields each part's body as a single section.
///
/// ```swift
/// let sequence = StreamingMultipartParserAsyncSequence(boundary: "boundary123", buffer: stream)
///
/// for try await section in sequence {
///     switch section {
///     case .headerFields(let fields): print(fields)
///     case .bodyChunk(let chunk): try await file.write(contentsOf: chunk)
///     case .boundary(let end): print(end ? "message finished" : "part finished")
///     }
/// }
/// ```
///
/// - Note: The sequence is single-pass. Iterating it more than once is not supported.
public struct StreamingMultipartParserAsyncSequence<BackingSequence: AsyncSequence>: AsyncSequence
where BackingSequence.Element: MultipartPartBodyElement {
    let parser: MultipartParser<BackingSequence.Element>
    let buffer: BackingSequence

    /// Creates a sequence that parses the multipart message carried by `buffer`.
    ///
    /// - Parameters:
    ///   - boundary: The boundary separating the parts of the message, without its leading
    ///     hyphens. For a message delimited by `--abc123`, pass `abc123`.
    ///   - buffer: An asynchronous sequence of chunks making up the multipart message. Chunks
    ///     may be split at any point; they need not line up with the message's structure.
    public init(boundary: String, buffer: BackingSequence) {
        self.parser = .init(boundary: boundary)
        self.buffer = buffer
    }

    /// An iterator over the sections of a streamed multipart message.
    public struct AsyncIterator: AsyncIteratorProtocol {
        /// The sections produced by this iterator.
        public typealias Element = MultipartSection<BackingSequence.Element>

        var parser: MultipartParser<BackingSequence.Element>
        var backingIterator: BackingSequence.AsyncIterator

        var pendingBodyChunk: BackingSequence.Element?

        var currentCollatedBody = BackingSequence.Element()

        /// Advances to the next section of the message.
        ///
        /// - Throws: ``MultipartParserError`` if the message is malformed, if it ends part-way
        ///   through a part, or if the backing sequence itself throws.
        /// - Returns: The next section, or `nil` once the message is complete.
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
                        if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
                            next = try await backingIterator.next(isolation: #isolation)
                        } else {
                            nonisolated(unsafe) var iterator = backingIterator
                            defer { backingIterator = iterator }
                            next = try await iterator.next()
                        }
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

        /// Advances to the next section, gathering each part's body chunks into a single section.
        ///
        /// Unlike ``next()``, which yields body chunks as they arrive, this method accumulates a
        /// part's body until the part ends and yields it whole. This is what backs
        /// ``MultipartParserAsyncSequence``, and it means the largest part of the message must fit
        /// in memory.
        ///
        /// - Throws: ``MultipartParserError`` if the message is malformed, if it ends part-way
        ///   through a part, or if the backing sequence itself throws.
        /// - Returns: The next section, or `nil` once the message is complete.
        public mutating func nextCollatedPart() async throws(MultipartParserError) -> MultipartSection<BackingSequence.Element>? {
            var headerFields = HTTPFields()

            while let part = try await self.next() {
                switch part {
                case .headerFields(let fields):
                    headerFields.append(contentsOf: fields)
                case .bodyChunk(let chunk):
                    self.currentCollatedBody.append(contentsOf: chunk)
                    if !headerFields.isEmpty {
                        defer { headerFields = .init() }
                        return .headerFields(headerFields)
                    }
                case .boundary:
                    if !currentCollatedBody.isEmpty {
                        defer { currentCollatedBody = .init() }
                        return .bodyChunk(currentCollatedBody)
                    }
                }
            }
            return nil
        }
    }

    /// Creates an iterator over the sections of the message.
    public func makeAsyncIterator() -> AsyncIterator {
        .init(parser: parser, backingIterator: buffer.makeAsyncIterator())
    }
}
