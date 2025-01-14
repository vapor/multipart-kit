struct NoOpAsyncSequence: AsyncSequence {
    typealias Element = ArraySlice<UInt8>

    struct Iterator: AsyncIteratorProtocol {
        mutating func next() async -> ArraySlice<UInt8>? {
            nil
        }
    }

    init() {}

    func makeAsyncIterator() -> Iterator {
        return Iterator()
    }
}
