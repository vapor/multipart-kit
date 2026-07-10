extension StreamingMultipartWriterAsyncSequence.AsyncIterator {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public mutating func next(isolation actor: isolated (any Actor)?) async throws(any Error) -> OutboundBody? {
        guard let section = try await backingIterator.next(isolation: actor) else {
            return nil
        }

        return try await serialize(section, isolation: actor)
    }
}
