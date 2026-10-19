extension Array where Element == ArraySlice<UInt8> {
    package var async: ChunkAsyncSequence {
        ChunkAsyncSequence(self)
    }
}

/// An asynchronous sequence of byte chunks that releases the reference to its array when an
/// iterator is created. So you can only iterate once.
///
/// > Warning: Not safe. Only for testing purposes.
package final class ChunkAsyncSequence: AsyncSequence, @unchecked Sendable {
    package typealias Element = ArraySlice<UInt8>

    package struct Iterator: AsyncIteratorProtocol {
        var iterator: [ArraySlice<UInt8>].Iterator

        init(_ iterator: [ArraySlice<UInt8>].Iterator) {
            self.iterator = iterator
        }

        public mutating func next() async -> ArraySlice<UInt8>? {
            iterator.next()
        }
    }

    private var base: [ArraySlice<UInt8>]?

    init(_ base: [ArraySlice<UInt8>]) {
        self.base = base
    }

    package func makeAsyncIterator() -> Iterator {
        defer { self.base = nil }  // release the reference so no CoW is triggered
        return Iterator(base.unsafelyUnwrapped.makeIterator())
    }
}
