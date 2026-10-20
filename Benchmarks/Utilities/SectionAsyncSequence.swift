import MultipartKit

extension Array where Element == MultipartSection<ArraySlice<UInt8>> {
    package var async: SectionAsyncSequence {
        SectionAsyncSequence(self)
    }
}

/// An asynchronous sequence of multipart sections that releases the reference to its array when an
/// iterator is created. So you can only iterate once.
///
/// > Warning: Not safe. Only for testing purposes.
package final class SectionAsyncSequence: AsyncSequence, @unchecked Sendable {
    package typealias Element = MultipartSection<ArraySlice<UInt8>>

    package struct Iterator: AsyncIteratorProtocol {
        var iterator: [MultipartSection<ArraySlice<UInt8>>].Iterator

        init(_ iterator: [MultipartSection<ArraySlice<UInt8>>].Iterator) {
            self.iterator = iterator
        }

        public mutating func next() async -> MultipartSection<ArraySlice<UInt8>>? {
            iterator.next()
        }
    }

    private var base: [MultipartSection<ArraySlice<UInt8>>]?

    init(_ base: [MultipartSection<ArraySlice<UInt8>>]) {
        self.base = base
    }

    package func makeAsyncIterator() -> Iterator {
        defer { self.base = nil }  // release the reference so no CoW is triggered
        return Iterator(base.unsafelyUnwrapped.makeIterator())
    }
}
