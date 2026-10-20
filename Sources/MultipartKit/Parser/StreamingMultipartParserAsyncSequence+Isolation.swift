import HTTPTypes

extension StreamingMultipartParserAsyncSequence.AsyncIterator {
    /// Advances to the next section of the message, inheriting the caller's actor isolation.
    ///
    /// - Parameter isolation: The actor to remain isolated to, defaulting to the caller's isolation.
    /// - Throws: ``MultipartParserError`` if the message is malformed, if it ends part-way
    ///   through a part, or if the backing sequence itself throws.
    /// - Returns: The next section, or `nil` once the message is complete.
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
                            pendingBodyChunk = chunk as? BackingSequence.Element ?? .init(chunk)
                            let returningFields = headerFields
                            headerFields = .init()
                            return .headerFields(returningFields)
                        }
                        return .bodyChunk(chunk as? BackingSequence.Element ?? .init(chunk))
                    case .boundary(let end):
                        return .boundary(end: end)
                    }
                }
            case .needMoreData:
                let next: BackingSequence.Element?
                do {
                    next = try await backingIterator.next(isolation: actor)
                } catch {
                    throw MultipartParserError.backingSequenceError(reason: "\(error)")
                }
                if let next {
                    parser.append(buffer: next as? ArraySlice<UInt8> ?? ArraySlice(next))
                } else {
                    switch parser.stateMachine.state {
                    case .finished:
                        return nil
                    case .initial, .parsing:
                        // `.initial` means no bytes arrived at all, which isn't a multipart message either.
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

    /// Advances to the next section, gathering each part's body chunks into a single section,
    /// inheriting the caller's actor isolation.
    ///
    /// - Parameter isolation: The actor to remain isolated to, defaulting to the caller's isolation.
    /// - Throws: ``MultipartParserError`` if the message is malformed, if it ends part-way
    ///   through a part, or if the backing sequence itself throws.
    /// - Returns: The next section, or `nil` once the message is complete.
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
                    hasPendingCollatedBody = true
                    return .headerFields(headerFields)
                }
            case .boundary:
                // A part whose header fields were returned gets its body too, even an empty one.
                if hasPendingCollatedBody || !currentCollatedBody.isEmpty {
                    defer {
                        currentCollatedBody = .init()
                        hasPendingCollatedBody = false
                    }
                    return .bodyChunk(currentCollatedBody)
                }
            }
        }
        return nil
    }
}
