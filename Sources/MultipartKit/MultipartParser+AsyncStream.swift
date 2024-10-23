public struct MultipartParseSequence: AsyncSequence {
    private let parser: MultipartParser
    private let buffer: AnyAsyncSequence<ArraySlice<UInt8>>

    public init<AS: AsyncSequence & Sendable>(boundary: String, buffer: AS) where AS.Element == ArraySlice<UInt8> {
        self.parser = .init(boundary: boundary)
        self.buffer = .init(buffer)
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(parser: parser, iterator: buffer.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var parser: MultipartParser
        private var iterator: AnyAsyncSequence<ArraySlice<UInt8>>.AsyncIterator

        init(parser: MultipartParser, iterator: AnyAsyncSequence<ArraySlice<UInt8>>.AsyncIterator) {
            self.parser = parser
            self.iterator = iterator
        }

        public mutating func next() async throws -> MultipartPart? {
            while true {
                switch try parser.read() {
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
                case .finished:
                    return nil
                }

            }
        }
    }
}
