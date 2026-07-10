extension StreamingMultipartWriterAsyncSequence.AsyncIterator {
    /// Advances to the next serialized chunk, inheriting the caller's actor isolation.
    ///
    /// Prefer this overload over ``next()`` where it is available: it forwards the isolation on to
    /// the backing sequence, avoiding a hop off the current actor for each section.
    ///
    /// - Parameter actor: The actor to remain isolated to.
    /// - Throws: Any error thrown by the backing sequence of sections.
    /// - Returns: The next chunk of serialized multipart data, or `nil` once the sections run out.
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public mutating func next(isolation actor: isolated (any Actor)?) async throws(any Error) -> OutboundBody? {
        while true {
            guard let section = try await backingIterator.next(isolation: actor) else {
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
