public import HTTPTypes

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
public struct StreamMultipartPart<BackingSequence: AsyncSequence, BodyChunk: MultipartPartBodyElement>: Sendable
where BackingSequence.Element == MultipartSection<BodyChunk> {
    public let headerFields: HTTPFields

    public let body: MultipartBodyAsyncSequence<BackingSequence, BodyChunk>
}

/// This iterates over a `StreamMultipartPart`'s body.
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
public struct MultipartBodyAsyncSequence<BackingSequence: AsyncSequence, BodyChunk: MultipartPartBodyElement>: AsyncSequence, Sendable
where BackingSequence.Element == MultipartSection<BodyChunk> {
    let sharedIterator: SharedIterator<BackingSequence, BodyChunk>

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = BodyChunk

        let sharedIterator: SharedIterator<BackingSequence, BodyChunk>

        public func next() async throws -> Element? {
            try await sharedIterator.nextBodyChunkForSubsequence()
        }

        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public func next(isolation actor: isolated (any Actor)? = #isolation) async throws(Failure) -> Element? {
            try await sharedIterator.nextBodyChunkForSubsequence()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(sharedIterator: sharedIterator)
    }
}

/// This sequence, based on top of an `AsyncSequence` which produces `MultipartSection`s,
/// produces `StreamMultipartPart`s, which are `MultipartPart`s made up of headers and a
/// streamable body.
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
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

        let sharedIterator: SharedIterator<BackingSequence, BodyChunk>

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

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
actor SharedIterator<
    BackingSequence: AsyncSequence,
    BodyChunk: MultipartPartBodyElement
> where BackingSequence.Element == MultipartSection<BodyChunk> {
    typealias BackingIterator = BackingSequence.AsyncIterator

    var pendingBodyChunk: BodyChunk?
    var pendingHeaderFields: HTTPFields?

    private var backingIterator: BackingIterator

    init(
        makeBackingIterator: @Sendable () -> BackingIterator,
        pendingBodyChunk: BodyChunk? = nil
    ) {
        self.backingIterator = makeBackingIterator()
        self.pendingBodyChunk = pendingBodyChunk
    }

    func nextPart() async throws -> StreamMultipartPart<BackingSequence, BodyChunk>? {
        var headerFields: HTTPFields = [:]

        if let pendingHeaderFields {
            headerFields.append(contentsOf: pendingHeaderFields)
            self.pendingHeaderFields = nil
        }

        while true {
            var iterator = backingIterator
            guard let next = try await iterator.next(isolation: self) else {
                backingIterator = iterator
                break
            }
            backingIterator = iterator
            switch next {
            case .headerFields(let fields):
                headerFields.append(contentsOf: fields)
            case .bodyChunk(let chunk):
                self.pendingBodyChunk = chunk
                let bodySequence = MultipartBodyAsyncSequence(sharedIterator: self)
                return StreamMultipartPart(headerFields: headerFields, body: bodySequence)
            case .boundary: return nil
            }
        }

        return nil
    }

    func nextBodyChunkForSubsequence() async throws -> BodyChunk? {
        if let pendingBodyChunk = self.pendingBodyChunk {
            defer { self.pendingBodyChunk = nil }
            return pendingBodyChunk
        }

        while true {
            var iterator = backingIterator
            guard let next = try await iterator.next(isolation: self) else {
                backingIterator = iterator
                break
            }
            backingIterator = iterator

            switch next {
            case .headerFields(let fields):
                pendingHeaderFields = fields
                return nil
            case .bodyChunk(let chunk): return chunk
            case .boundary: return nil
            }
        }

        return nil
    }
}
