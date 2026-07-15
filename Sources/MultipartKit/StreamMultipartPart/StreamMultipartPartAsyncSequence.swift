import HTTPTypes

/// This sequence, based on top of an `AsyncSequence` which produces ``MultipartSection``s,
/// produces ``StreamMultipartPart``s, which are ``MultipartPart``s made up of headers and a
/// streamable body.
public struct StreamMultipartPartAsyncSequence<
    BackingSequence: AsyncSequence & Sendable,
    BodyChunk: MultipartPartBodyElement
>: AsyncSequence where BackingSequence.Element == MultipartSection<BodyChunk> {
    let makeBackingIterator: @Sendable () -> BackingSequence.AsyncIterator

    public init(backingSequence: BackingSequence) {
        self.makeBackingIterator = { backingSequence.makeAsyncIterator() }
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = StreamMultipartPart<BackingSequence, BodyChunk>

        let sharedIterator: StreamMultipartPartSharedIterator<BackingSequence, BodyChunk>

        public func next() async throws -> Element? {
            try await sharedIterator.nextPart()
        }

        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public func next(isolation actor: isolated (any Actor)? = #isolation) async throws(Failure) -> Element? {
            try await sharedIterator.nextPart()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(sharedIterator: .init(makeBackingIterator: makeBackingIterator))
    }
}
