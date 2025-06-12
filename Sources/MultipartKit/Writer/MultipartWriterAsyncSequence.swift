/// An async sequence that converts a sequence of ``MultipartSection`` values into serialized multipart data chunks.
///
/// This streaming writer processes multipart sections on-demand, making it memory-efficient for large
/// multipart messages. It's particularly useful when working with file uploads or when you need to
/// stream multipart data without buffering the entire message in memory.
///
/// ```swift
/// let sections: [MultipartSection<ArraySlice<UInt8>>] = [
///     .headerFields([.contentType: "text/plain"]),
///     .bodyChunk(ArraySlice("Hello, world!".utf8)),
///     .boundary(end: true)
/// ]
///
/// let writer = StreamingMultipartWriterAsyncSequence(
///     backingSequence: sections.async,
///     boundary: "boundary123"
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

        private var needsCRLFAfterBody: Bool
        private var backingIterator: BackingSequence.AsyncIterator
        private var writer: EmbeddedWriter

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

        /// Advances to the next serialized chunk of multipart data.
        ///
        /// - Returns: The next chunk of serialized multipart data, or `nil` if the sequence is complete.
        /// - Throws: Any error that occurs during serialization.
        public mutating func next() async throws -> OutboundBody? {
            while true {
                guard let section = try await backingIterator.next() else {
                    return nil
                }

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
        }
    }
}
