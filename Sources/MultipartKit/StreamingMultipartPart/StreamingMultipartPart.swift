public import HTTPTypes

/// A single part of a multipart-encoded message whose body is streamed rather than buffered.
///
/// This is the streaming counterpart to ``MultipartPart``: instead of holding the whole body in
/// memory, ``body`` is an `AsyncSequence` of chunks produced on demand. Parts of this kind are
/// yielded by ``StreamingMultipartPartAsyncSequence`` and expanded back into sections by
/// ``StreamingMultipartSectionAsyncSequence``, which makes them suited to large parts such as
/// file uploads.
///
/// - Note: A part's ``body`` shares a single underlying cursor with the sequence that produced it,
///   so it must be fully consumed before the next part is requested.
public struct StreamingMultipartPart<Body: AsyncSequence & Sendable>: Sendable
where Body.Element: MultipartPartBodyElement {
    /// The header fields for this part.
    public let headerFields: HTTPFields

    /// The streamed body of this part.
    public let body: Body

    /// Creates a new ``StreamingMultipartPart``.
    ///
    /// - Parameters:
    ///   - headerFields: The header fields for this part.
    ///   - body: The streamed body of this part.
    public init(headerFields: HTTPFields, body: Body) {
        self.headerFields = headerFields
        self.body = body
    }
}

/// An error thrown while consuming a ``StreamingMultipartPartAsyncSequence``.
// TODO: Make this @nonexhaustive when we drop 6.1
public struct StreamingMultipartPartError: Error, Equatable {
    enum Backing {
        case nextPartRequestedWhileStreamingPreviousBody
    }

    let backing: Backing

    init(_ backing: Backing) {
        self.backing = backing
    }

    /// The next part was requested before the current part's body had been fully consumed.
    ///
    /// The parts and their bodies share a single underlying cursor, so each part's
    /// ``StreamingMultipartPart/body`` must be fully consumed before the next part is requested.
    public static let nextPartRequestedWhileStreamingPreviousBody = Self(.nextPartRequestedWhileStreamingPreviousBody)
}
