public struct NoOpAsyncSequence: AsyncSequence {
    public typealias Element = ArraySlice<UInt8>

    public init() {}

    public struct Iterator: AsyncIteratorProtocol {
        public mutating func next() async -> Element? {
            nil
        }
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator()
    }
}
