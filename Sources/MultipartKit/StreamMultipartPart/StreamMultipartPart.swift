public import HTTPTypes

public struct StreamMultipartPart<BackingSequence: AsyncSequence, BodyChunk: MultipartPartBodyElement>: Sendable
where BackingSequence.Element == MultipartSection<BodyChunk> {
    public let headerFields: HTTPFields

    public let body: MultipartBodyAsyncSequence<BackingSequence, BodyChunk>
}

@nonexhaustive public enum StreamMultipartPartError: Error {
    case nextPartRequestedWhileStreamingPreviousBody
}
