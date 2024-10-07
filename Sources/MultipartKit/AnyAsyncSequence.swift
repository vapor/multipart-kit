@usableFromInline
struct AnyAsyncSequence<Element>: AsyncSequence {
    @usableFromInline
    typealias AsyncIteratorNextCallback = () async throws -> Element?

    @usableFromInline
    let makeAsyncIteratorCallback: @Sendable () -> AsyncIteratorNextCallback

    @inlinable
    init<AS: AsyncSequence>(_ base: AS) where AS.Element == Element, AS: Sendable {
        self.makeAsyncIteratorCallback = {
            var iterator = base.makeAsyncIterator()
            return {
                try await iterator.next()
            }
        }
    }

    @usableFromInline
    struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline
        let nextCallback: AsyncIteratorNextCallback

        @usableFromInline
        init(nextCallback: @escaping AsyncIteratorNextCallback) {
            self.nextCallback = nextCallback
        }

        @inlinable
        func next() async throws -> Element? {
            try await self.nextCallback()
        }
    }

    @inlinable
    func makeAsyncIterator() -> AsyncIterator {
        .init(nextCallback: self.makeAsyncIteratorCallback())
    }
}

extension AnyAsyncSequence: Sendable where Element: Sendable {}
