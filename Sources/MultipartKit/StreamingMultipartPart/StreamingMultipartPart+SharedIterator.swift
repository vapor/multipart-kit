import HTTPTypes

actor StreamingMultipartPartSharedIterator<
    BackingSequence: AsyncSequence,
    BodyChunk: MultipartPartBodyElement
> where BackingSequence.Element == MultipartSection<BodyChunk> {
    typealias BackingIterator = BackingSequence.AsyncIterator
    typealias Element = StreamingMultipartPart<StreamingMultipartPartBody<BackingSequence, BodyChunk>>?

    var pendingBodyChunk: BodyChunk?

    private var backingIterator: BackingIterator
    private var stateMachine: StateMachine
    private var isReading: Bool

    init(
        makeBackingIterator: @Sendable () -> BackingIterator,
        pendingBodyChunk: BodyChunk? = nil
    ) {
        self.backingIterator = makeBackingIterator()
        self.pendingBodyChunk = pendingBodyChunk
        self.stateMachine = .init()
        self.isReading = false
    }

    func nextPart() async throws -> Element {
        precondition(!isReading, "Streaming multipart message was iterated concurrently")
        isReading = true
        defer { isReading = false }

        switch stateMachine.nextPart() {
        case .currentlyStreamingBody:
            throw StreamingMultipartPartError.nextPartRequestedWhileStreamingPreviousBody
        case .noMoreParts: return nil
        case .goodToGo: break
        }

        // if nextPartResult == .goodToGo

        var headerFields: HTTPFields = [:]

        while true {
            nonisolated(unsafe) var iterator = backingIterator
            defer { backingIterator = iterator }

            let next: MultipartSection<BodyChunk>?
            if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
                next = try await iterator.next(isolation: self)
            } else {
                next = try await iterator.next()
            }

            guard let next else { break }

            switch next {
            case .headerFields(let fields):
                headerFields.append(contentsOf: fields)
            case .bodyChunk(let chunk):
                let id = stateMachine.bodyStreamingStarted()
                self.pendingBodyChunk = chunk
                let bodySequence = StreamingMultipartPartBody(sharedIterator: self, id: id)
                return StreamingMultipartPart(headerFields: headerFields, body: bodySequence)
            case .boundary(let end):
                if headerFields.isEmpty {
                    if end {
                        stateMachine.finish()
                        return nil
                    }
                    stateMachine.partStreamingEnded()
                    continue
                } else {
                    // headers but no body chunk = a part with an empty body
                    let id = stateMachine.bodyStreamingStarted()
                    if end {
                        stateMachine.finish()
                    } else {
                        stateMachine.partStreamingEnded()
                    }
                    // state has already moved past `id`, so this body is inert
                    let body = StreamingMultipartPartBody(sharedIterator: self, id: id)
                    return StreamingMultipartPart(headerFields: headerFields, body: body)
                }
            }
        }

        return nil
    }

    func nextBodyChunkForSubsequence(id: Int) async throws -> BodyChunk? {
        precondition(!isReading, "StreamingMultipartPart body was iterated concurrently")
        isReading = true
        defer { isReading = false }

        switch stateMachine.nextChunk(id: id) {
        case .goodToGo: break
        case .endOfBody: return nil
        }

        if let pendingBodyChunk {
            self.pendingBodyChunk = nil
            return pendingBodyChunk
        }

        nonisolated(unsafe) var iterator = backingIterator
        defer { backingIterator = iterator }

        let next: MultipartSection<BodyChunk>?
        if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
            next = try await iterator.next(isolation: self)
        } else {
            next = try await iterator.next()
        }

        guard let next else { return nil }

        switch next {
        case .headerFields:
            return nil
        case .bodyChunk(let chunk):
            return chunk
        case .boundary(let end):
            if end {
                stateMachine.finish()
            } else {
                stateMachine.partStreamingEnded()
            }
            return nil
        }
    }
}
