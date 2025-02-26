import HTTPTypes

extension StreamingMultipartParserAsyncSequence.AsyncIterator {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public mutating func next(isolation actor: isolated (any Actor)? = #isolation) async throws(MultipartParserError) -> Self.Element? {
        if let pendingBodyChunk {
            defer { self.pendingBodyChunk = nil }
            return .bodyChunk(pendingBodyChunk)
        }

        var headerFields = HTTPFields()

        while true {
            switch parser.read() {
            case .success(let optionalPart):
                switch optionalPart {
                case .none: continue
                case .some(let part):
                    switch part {
                    case .headerFields(let fields):
                        headerFields.append(contentsOf: fields)
                        continue
                    case .bodyChunk(let chunk):
                        if !headerFields.isEmpty {
                            pendingBodyChunk = chunk
                            let returningFields = headerFields
                            headerFields = .init()
                            return .headerFields(returningFields)
                        }
                        return .bodyChunk(chunk)
                    case .boundary:
                        return part
                    }
                }
            case .needMoreData:
                let next: BackingSequence.Element?
                do {
                    next = try await iterator.next(isolation: actor)
                } catch {
                    throw MultipartParserError.backingSequenceError(reason: "\(error)")
                }
                if let next {
                    parser.append(buffer: next)
                } else {
                    switch parser.state {
                    case .initial, .finished:
                        return nil
                    case .parsing:
                        throw MultipartParserError.unexpectedEndOfFile
                    }
                }
            case .error(let error):
                throw error
            case .finished:
                return nil
            }
        }
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public mutating func nextCollatedPart(isolation actor: isolated (any Actor)? = #isolation) async throws(MultipartParserError)
        -> MultipartSection<BackingSequence.Element>?
    {
        var headerFields = HTTPFields()

        while let part = try await self.next(isolation: actor) {
            switch part {
            case .headerFields(let fields):
                headerFields.append(contentsOf: fields)
            case .bodyChunk(let chunk):
                self.currentCollatedBody.append(contentsOf: chunk)
                if !headerFields.isEmpty {
                    defer { headerFields = .init() }
                    return .headerFields(headerFields)
                }
            case .boundary:
                if !currentCollatedBody.isEmpty {
                    defer { currentCollatedBody = .init() }
                    return .bodyChunk(currentCollatedBody)
                }
            }
        }
        return nil
    }
}
