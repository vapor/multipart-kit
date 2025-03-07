public struct MultipartSerializerAsyncSequence<
    BackingSequence: AsyncSequence,
    BackingElement: MultipartPartBodyElement
>: AsyncSequence
where 
    BackingSequence.Element == MultipartSection<BackingElement>,
    BackingElement: RangeReplaceableCollection
{    
    let serializer: MultipartSerializer<BackingElement>
    let buffer: BackingSequence

    public init(boundary: String, backingSequence: BackingSequence) {
        self.serializer = .init(boundary: boundary)
        self.buffer = backingSequence
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = BackingElement

        var serializer: MultipartSerializer<BackingElement>
        var iterator: BackingSequence.AsyncIterator

        public mutating func next() async throws -> BackingElement? {
            while true {
                switch serializer.write() {
                case .serialized(let optionalPart):
                    switch optionalPart {
                    case .none: continue
                    case .some(let part): return part
                    }
                case .needMoreData:
                    if let next = try await iterator.next() {
                        serializer.append(next)
                    } else {
                        switch serializer.state {
                        case .initial, .finished: return nil
                        case .serializing: fatalError("EOF")
                        }
                    }
                case .error: fatalError("Stuff?")
                case .finished: return nil
                }
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        .init(serializer: serializer, iterator: buffer.makeAsyncIterator())
    }
}
