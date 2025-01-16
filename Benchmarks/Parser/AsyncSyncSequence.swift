extension Sequence {
    var async: AsyncSyncSequence<Self> {
        AsyncSyncSequence(self)
    }
}

/// An asynchronous sequence composed from a synchronous sequence, that releases the reference to
/// the base sequence when an iterator is created. So you can only iterate once.
///
/// Not safe. Only for testing purposes.
/// Use `swift-algorithms`'s `AsyncSyncSequence`` instead if you're looking for something like this.
final class AsyncSyncSequence<Base: Sequence>: AsyncSequence {
    typealias Element = Base.Element

    struct Iterator: AsyncIteratorProtocol {
        var iterator: Base.Iterator?

        init(_ iterator: Base.Iterator) {
            self.iterator = iterator
        }

        mutating func next() async -> Base.Element? {
            iterator?.next()
        }
    }

    private var base: Base?

    init(_ base: Base) {
        self.base = base
    }

    func makeAsyncIterator() -> Iterator {
        defer { self.base = nil }  // release the reference so no CoW is triggered
        return Iterator(base.unsafelyUnwrapped.makeIterator())
    }
}
