/// An async sequence that converts a sequence of ``MultipartSection`` values into serialized multipart data chunks.
///
/// This streaming writer processes multipart sections on-demand, making it memory-efficient for large
/// multipart messages. It's particularly useful when working with file uploads or when you need to
/// stream multipart data without buffering the entire message in memory.
///
/// It is the mirror image of ``StreamingMultipartParserAsyncSequence``, and serializes exactly the
/// sections it is given: the boundaries separating the parts, and the one ending the message, have
/// to appear in the backing sequence. A part is a `.boundary(end: false)`, then its
/// `.headerFields`, then one or more `.bodyChunk`s.
///
/// ```swift
/// let sections: [MultipartSection<ArraySlice<UInt8>>] = [
///     .boundary(end: false),
///     .headerFields([.contentType: "text/plain"]),
///     .bodyChunk(ArraySlice("Hello, world!".utf8)),
///     .boundary(end: true),
/// ]
///
/// let writer = StreamingMultipartWriterAsyncSequence(
///     backingSequence: sections.async,  // any AsyncSequence of sections
///     boundary: "boundary123",
///     outboundBody: ArraySlice<UInt8>.self
/// )
///
/// for try await chunk in writer {
///     // Process each serialized chunk
/// }
/// ```
public struct StreamingMultipartWriterAsyncSequence<
    OutboundBody: MultipartPartBodyElement,
    BackingSequence: AsyncSequence,
    BackingBody: MultipartPartBodyElement
>: AsyncSequence
where
    BackingSequence.Element == MultipartSection<BackingBody>,
    BackingBody: MultipartPartBodyElement
{
    private let backingSequence: BackingSequence
    private let boundary: String

    /// Creates a new streaming multipart writer async sequence.
    ///
    /// - Parameters:
    ///   - backingSequence: The async sequence of multipart sections to serialize.
    ///   - boundary: The boundary string to use for separating multipart parts.
    ///   - outboundBody: The type of the output body elements (inferred from usage).
    public init(
        backingSequence: BackingSequence,
        boundary: String,
        outboundBody: OutboundBody.Type = OutboundBody.self
    ) {
        self.backingSequence = backingSequence
        self.boundary = boundary
    }

    /// Creates an iterator over the serialized chunks of the message.
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            backingIterator: backingSequence.makeAsyncIterator(),
            boundary: boundary
        )
    }

    /// The async iterator for the streaming multipart writer.
    ///
    /// This iterator processes multipart sections one at a time and yields serialized chunks
    /// of the multipart message. It maintains state to ensure proper formatting of boundaries
    /// and CRLF sequences between parts.
    public struct AsyncIterator: AsyncIteratorProtocol {
        /// An embedded writer implementation used internally for serialization.
        struct EmbeddedWriter: MultipartWriter {
            let boundary: String
            var buffer: OutboundBody

            /// Creates a new embedded writer with the specified boundary.
            ///
            /// - Parameter boundary: The boundary string to use.
            init(boundary: String) {
                self.boundary = boundary
                self.buffer = .init()
            }

            mutating func write(bytes: some Collection<UInt8> & Sendable) async throws {
                buffer.append(contentsOf: bytes)
            }
        }

        var needsCRLFAfterBody: Bool
        var backingIterator: BackingSequence.AsyncIterator
        var writer: EmbeddedWriter

        /// Creates a new async iterator.
        ///
        /// - Parameters:
        ///   - backingIterator: The iterator from the backing sequence.
        ///   - boundary: The boundary string to use.
        init(
            backingIterator: BackingSequence.AsyncIterator,
            boundary: String
        ) {
            self.backingIterator = backingIterator
            self.writer = .init(boundary: boundary)
            self.needsCRLFAfterBody = false
        }

        /// Serializes a single section into the writer's buffer and returns it.
        ///
        /// Shared by ``next()`` and ``next(isolation:)``, which differ only in how they
        /// obtain the next section from the backing iterator.
        mutating func serialize(
            _ section: MultipartSection<BackingBody>,
            isolation: isolated (any Actor)? = #isolation
        ) async throws -> OutboundBody {
            writer.buffer.removeAll(keepingCapacity: true)

            switch section {
            case .boundary(let end):
                if needsCRLFAfterBody {
                    needsCRLFAfterBody = false
                    try await writer.write(bytes: ArraySlice.crlf)
                }
                try await writer.writeBoundary(end: end)
            case .headerFields(let fields):
                try await writer.writeHeaders(fields)
            case .bodyChunk(let chunk):
                try await writer.writeBodyChunk(chunk)
                self.needsCRLFAfterBody = true
            }

            return writer.buffer
        }

        /// Advances to the next serialized chunk of multipart data.
        ///
        /// - Returns: The next chunk of serialized multipart data, or `nil` if the sequence is complete.
        /// - Throws: Any error that occurs during serialization.
        public mutating func next() async throws -> OutboundBody? {
            let section: MultipartSection<BackingBody>?
            if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
                section = try await backingIterator.next(isolation: #isolation)
            } else {
                nonisolated(unsafe) var iterator = backingIterator
                defer { backingIterator = iterator }
                section = try await iterator.next()
            }

            guard let section else { return nil }

            return try await serialize(section)
        }
    }
}
