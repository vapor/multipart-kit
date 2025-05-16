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
    private let writer: BufferedMultipartWriter<OutboundBody>

    public init(
        backingSequence: BackingSequence,
        boundary: String,
        outboundBody: OutboundBody.Type = OutboundBody.self
    ) {
        self.backingSequence = backingSequence
        self.writer = .init(boundary: boundary)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var backingIterator: BackingSequence.AsyncIterator
        private var writer: BufferedMultipartWriter<OutboundBody>

        enum State: Equatable {
            enum Part {
                case boundary
                case headerFields
                case bodyChunk
            }

            case initial
            case wrote(Part)
            case finished
        }

        private var state: State

        init(
            backingIterator: BackingSequence.AsyncIterator,
            writer: BufferedMultipartWriter<OutboundBody>
        ) {
            self.backingIterator = backingIterator
            self.writer = writer
            self.state = .initial
        }

        public mutating func next() async throws -> OutboundBody? {
            while true {
                switch try await backingIterator.next() {
                case .boundary(let end):
                    if state == .wrote(.bodyChunk) {
                        writer.write(bytes: ArraySlice.crlf)
                    }
                    try await writer.writeBoundary(end: end)
                    state = .wrote(.boundary)
                case .headerFields(let fields):
                    try await writer.writeHeaders(fields)
                    state = .wrote(.headerFields)
                case .bodyChunk(let chunk):
                    writer.writeBodyChunk(chunk)
                    state = .wrote(.bodyChunk)
                case nil:
                    return nil
                }

                return writer.getResult()
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            backingIterator: backingSequence.makeAsyncIterator(),
            writer: writer
        )
    }

}
