import HTTPTypes

/// An asynchronous sequence that groups a stream of ``MultipartSection``s into ``StreamingMultipartPart``s.
///
/// This sequence groups ``MultipartSection``s into parts, each made up of its header fields and a streamed
/// ``StreamingMultipartPart/body``. The body is produced on demand, so a part is never held in memory
/// in its entirety, which makes the sequence suited to large messages such as file uploads.
///
/// ```swift
/// let parts = StreamingMultipartPartAsyncSequence(backingSequence: sections)
///
/// for try await part in parts {
///     print(part.headerFields)
///     for try await chunk in part.body {
///         try await file.write(contentsOf: chunk)
///     }
/// }
/// ```
///
/// - Note: The parts and their bodies share a single underlying cursor, so each part's body must be
///   fully consumed, and parts consumed in order. Requesting the next part while a body is still
///   streaming throws ``StreamingMultipartPartError/nextPartRequestedWhileStreamingPreviousBody``.
public struct StreamingMultipartPartAsyncSequence<
    BackingSequence: AsyncSequence & Sendable,
    BodyChunk: MultipartPartBodyElement
>: AsyncSequence, Sendable where BackingSequence.Element == MultipartSection<BodyChunk> {
    let makeBackingIterator: @Sendable () -> BackingSequence.AsyncIterator

    /// Creates a sequence that groups the sections produced by `backingSequence` into parts.
    ///
    /// - Parameter backingSequence: An asynchronous sequence of ``MultipartSection``s, such as a
    ///   ``StreamingMultipartParserAsyncSequence``.
    public init(backingSequence: BackingSequence) {
        self.makeBackingIterator = { backingSequence.makeAsyncIterator() }
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = StreamingMultipartPart<StreamingMultipartPartBody<BackingSequence, BodyChunk>>

        let sharedIterator: StreamingMultipartPartSharedIterator<BackingSequence, BodyChunk>

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
