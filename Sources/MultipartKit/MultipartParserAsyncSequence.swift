public struct MultipartParserAsyncSequence<BackingSequence: AsyncSequence>: AsyncSequence where BackingSequence.Element: Collection<UInt8> {
    private let parser: MultipartParser
    private let buffer: BackingSequence

    public init(boundary: String, buffer: BackingSequence) {
        self.parser = .init(boundary: boundary)
        self.buffer = buffer
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(parser: parser, iterator: buffer.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var parser: MultipartParser
        private var iterator: BackingSequence.AsyncIterator

        init(parser: MultipartParser, iterator: BackingSequence.AsyncIterator) {
            self.parser = parser
            self.iterator = iterator
        }

        public mutating func next() async throws -> MultipartSection? {
            while true {
                switch parser.read() {
                case .success(let optionalPart):
                    switch optionalPart {
                    case .none: continue
                    case .some(let part): return part
                    }
                case .needMoreData:
                    guard let next = try await iterator.next() else {
                        return nil
                    }
                    parser.append(buffer: next)
                case .error(let error):
                    throw error
                case .finished:
                    return nil
                }

            }
        }
    }
}