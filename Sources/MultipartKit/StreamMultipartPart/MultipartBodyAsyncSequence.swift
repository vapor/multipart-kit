/// This iterates over a `StreamMultipartPart`'s body.
public struct MultipartBodyAsyncSequence<BackingSequence: AsyncSequence, BodyChunk: MultipartPartBodyElement>: AsyncSequence, Sendable
where BackingSequence.Element == MultipartSection<BodyChunk> {
    let sharedIterator: StreamMultipartPartSharedIterator<BackingSequence, BodyChunk>
    let id: Int

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = BodyChunk

        let sharedIterator: StreamMultipartPartSharedIterator<BackingSequence, BodyChunk>
        let id: Int

        public func next() async throws -> Element? {
            try await sharedIterator.nextBodyChunkForSubsequence(id: id)
        }

        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public func next(isolation actor: isolated (any Actor)? = #isolation) async throws(Failure) -> Element? {
            try await sharedIterator.nextBodyChunkForSubsequence(id: id)
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(sharedIterator: sharedIterator, id: id)
    }
}
