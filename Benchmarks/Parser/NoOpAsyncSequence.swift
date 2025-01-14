struct NoOpAsyncSequence: AsyncSequence {
    typealias Element = ArraySlice<UInt8>

    struct Iterator: AsyncIteratorProtocol {
        mutating func next() async -> Element? {
            nil
        }
    }

    func makeAsyncIterator() -> Iterator {
        return Iterator()
    }
}
