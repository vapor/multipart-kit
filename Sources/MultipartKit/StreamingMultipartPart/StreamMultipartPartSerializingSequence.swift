import HTTPTypes

/// This sequence, based on top of an `AsyncSequence` which produces ``StreamingMultipartPart``s,
/// produces ``StreamMultipartSection``s.
public struct StreamingMultipartSectionAsyncSequence<
    Parts: AsyncSequence & Sendable,
    Body: AsyncSequence & Sendable
>: AsyncSequence, Sendable
where
    Parts.Element == StreamingMultipartPart<Body>,
    Body.Element: MultipartPartBodyElement
{
    public typealias BodyChunk = Body.Element

    let makeBackingIterator: @Sendable () -> Parts.AsyncIterator

    public init(parts: Parts) {
        self.makeBackingIterator = { parts.makeAsyncIterator() }
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = MultipartSection<BodyChunk>

        var stateMachine: StateMachine

        init(backingIterator: Parts.AsyncIterator) {
            self.stateMachine = .init(backingIterator: backingIterator)
        }

        public mutating func next() async throws -> MultipartSection<BodyChunk>? {
            try await stateMachine.next()
        }

        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public mutating func next(isolation actor: isolated (any Actor)? = #isolation) async throws(Failure) -> Element? {
            try await stateMachine.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(backingIterator: makeBackingIterator())
    }
}

extension StreamingMultipartSectionAsyncSequence {
    struct StateMachine {
        enum State {
            case initial
            case emitHeaders(StreamingMultipartPart<Body>)
            case streamingBody(Body.AsyncIterator)
            case finished
        }

        var state: State = .initial
        var backingIterator: Parts.AsyncIterator

        mutating func next() async throws -> MultipartSection<BodyChunk>? {
            switch state {
            case .initial:
                guard let part = try await nextPart() else {
                    return finish()
                }
                state = .emitHeaders(part)
                return .boundary(end: false)

            case .emitHeaders(let part):
                state = .streamingBody(part.body.makeAsyncIterator())
                return .headerFields(part.headerFields)

            case .streamingBody(var body):
                if let chunk = try await body.nextChunk() {
                    state = .streamingBody(body)
                    return .bodyChunk(chunk)
                }
                guard let part = try await nextPart() else {
                    return finish()
                }
                state = .emitHeaders(part)
                return .boundary(end: false)

            case .finished:
                return nil
            }
        }

        mutating func finish() -> MultipartSection<BodyChunk> {
            self.state = .finished
            return .boundary(end: true)
        }

        mutating func nextPart() async throws -> StreamingMultipartPart<Body>? {
            if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
                return try await backingIterator.next(isolation: #isolation)
            } else {
                nonisolated(unsafe) var iterator = backingIterator
                defer { backingIterator = iterator }
                return try await iterator.next()
            }
        }
    }
}

extension AsyncIteratorProtocol where Element: MultipartPartBodyElement {
    fileprivate mutating func nextChunk() async throws -> Element? {
        if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
            return try await self.next(isolation: #isolation)
        } else {
            nonisolated(unsafe) var iterator = self
            defer { self = iterator }
            return try await iterator.next()
        }
    }
}
