package struct NoOpAsyncSequence: AsyncSequence {
    package typealias Element = ArraySlice<UInt8>

    package init() {}

    package struct Iterator: AsyncIteratorProtocol {
        package mutating func next() async -> Element? {
            nil
        }
    }

    package func makeAsyncIterator() -> Iterator {
        return Iterator()
    }
}
