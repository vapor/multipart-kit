import HTTPTypes

extension StreamMultipartPartSharedIterator {
    struct StateMachine {
        enum State {
            case initial
            case streamingBody(id: Int)
            case betweenParts
            case finished
        }

        var state: State
        var latestBodyID: Int = -1

        init() {
            self.state = .initial
        }

        // Read state methods

        enum NextPartResult {
            case goodToGo
            case currentlyStreamingBody
            case noMoreParts
        }

        mutating func nextPart() -> NextPartResult {
            switch state {
            case .initial, .betweenParts:
                .goodToGo
            case .streamingBody: .currentlyStreamingBody
            case .finished: .noMoreParts
            }
        }

        enum NextChunkResult {
            case goodToGo
            case endOfBody
        }

        mutating func nextChunk(id: Int) -> NextChunkResult {
            switch state {
            case .streamingBody(let currentID) where currentID == id: .goodToGo
            case .initial, .betweenParts, .finished, .streamingBody:
                .endOfBody
            }
        }

        // Write state methods

        mutating func bodyStreamingStarted() -> Int {
            latestBodyID += 1
            self.state = .streamingBody(id: latestBodyID)
            return latestBodyID
        }

        mutating func partStreamingEnded() {
            self.state = .betweenParts
        }

        mutating func finish() {
            self.state = .finished
        }
    }
}
