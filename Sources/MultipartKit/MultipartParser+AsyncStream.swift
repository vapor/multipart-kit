struct MultipartParseSequence: AsyncSequence {
    private let parser: MultipartParser
    private let buffer: AnyAsyncSequence<ArraySlice<UInt8>>
    private let chunkSize: Int

    func makeAsyncIterator() -> Iterator {}

    struct Iterator: AsyncIteratorProtocol {
        typealias Element = MultipartPart

        private var parser: MultipartParser

        mutating func next() async throws -> MultipartPart? {
            while true {
                switch try parser.read() {
                case .success(let readPart):
                    if let readPart { return readPart }
                case .needMoreData:
                    break
                }
            }
        }
    }
}
