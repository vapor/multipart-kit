//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Async Algorithms open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

extension Array<ArraySlice<UInt8>> {
    var async: AsyncSyncSequence {
        AsyncSyncSequence(self)
    }
}

/// An asynchronous sequence composed from a synchronous sequence, that releases the reference to
/// the base sequence when an iterator is created. So you can only iterate once.
///
/// Not safe. Only for testing purposes.
/// Use `swift-algorithms`'s `AsyncSyncSequence`` instead if you're looking for something like this.
final class AsyncSyncSequence: AsyncSequence {
    typealias Base = Array<ArraySlice<UInt8>>
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

    var base: Base?

    init(_ base: Base) {
        self.base = base
    }

    func makeAsyncIterator() -> Iterator {
        defer { self.base = nil } // release the reference so no CoW is triggered
        return Iterator(base.unsafelyUnwrapped.makeIterator())
    }
}
