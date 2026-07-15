extension StreamingMultipartWriterAsyncSequence.AsyncIterator {
    /// Advances to the next serialized chunk, inheriting the caller's actor isolation.
    ///
    /// - Parameter actor: The actor to remain isolated to.
    /// - Throws: Any error thrown by the backing sequence of sections.
    /// - Returns: The next chunk of serialized multipart data, or `nil` once the sections run out.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public mutating func next(isolation actor: isolated (any Actor)? = #isolation) async throws(any Error) -> OutboundBody? {
        guard let section = try await backingIterator.next(isolation: actor) else {
            return nil
        }

        return try await serialize(section, isolation: actor)
    }
}
