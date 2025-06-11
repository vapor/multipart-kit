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

    public struct AsyncIterator: AsyncIteratorProtocol {
        struct EmbeddedWriter: MultipartWriter {
            var boundary: String
            var buffer: OutboundBody

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

        init(
            backingIterator: BackingSequence.AsyncIterator,
            boundary: String
        ) {
            self.backingIterator = backingIterator
            self.writer = .init(boundary: boundary)
            self.needsCRLFAfterBody = false
        }

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
