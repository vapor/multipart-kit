extension StreamingMultipartSectionAsyncSequence.StateMachine {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    mutating func next(isolation actor: isolated (any Actor)? = #isolation) async throws -> MultipartSection<Body.Element>? {
        switch state {
        case .initial:
            guard let part = try await nextPart(isolation: actor) else { return finish() }
            state = .emitHeaders(part)
            return .boundary(end: false)
        case .emitHeaders(let part):
            state = .streamingBody(part.body.makeAsyncIterator())
            return .headerFields(part.headerFields)
        case .streamingBody(var body):
            if let chunk = try await body.nextChunk(isolation: actor) {
                state = .streamingBody(body)
                return .bodyChunk(chunk)
            }
            guard let part = try await nextPart(isolation: actor) else { return finish() }
            state = .emitHeaders(part)
            return .boundary(end: false)
        case .finished:
            return nil
        }
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    mutating func nextPart(isolation actor: isolated (any Actor)? = #isolation) async throws -> StreamingMultipartPart<Body>? {
        try await backingIterator.next(isolation: #isolation)
    }
}

extension AsyncIteratorProtocol where Element: MultipartPartBodyElement {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    fileprivate mutating func nextChunk(isolation actor: isolated (any Actor)? = #isolation) async throws -> Element? {
        try await self.next(isolation: #isolation)
    }
}
