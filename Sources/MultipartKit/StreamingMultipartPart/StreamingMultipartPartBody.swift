/// This iterates over a `StreamingMultipartPart`'s body.
public struct StreamingMultipartPartBody<BackingSequence: AsyncSequence, BodyChunk: MultipartPartBodyElement>: AsyncSequence, Sendable
where BackingSequence.Element == MultipartSection<BodyChunk> {
    let sharedIterator: StreamingMultipartPartSharedIterator<BackingSequence, BodyChunk>
    let id: Int

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = BodyChunk

        let sharedIterator: StreamingMultipartPartSharedIterator<BackingSequence, BodyChunk>
        let id: Int

        public func next() async throws -> Element? {
            try await sharedIterator.nextBodyChunkForSubsequence(id: id)
        }

        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public func next(isolation actor: isolated (any Actor)? = #isolation) async throws -> Element? {
            try await sharedIterator.nextBodyChunkForSubsequence(id: id)
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(sharedIterator: sharedIterator, id: id)
    }
}
