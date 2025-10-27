import HTTPTypes

/// Represents a section of a multipart message during parsing or serialization.
///
/// Multipart messages are composed of different types of sections that appear in sequence:
/// boundaries that separate parts, header fields that describe each part, and body chunks
/// that contain the actual data.
///
/// This enum is used by both parsers and writers to represent the structure of multipart
/// messages in a streaming fashion, allowing for memory-efficient processing of large messages.
public enum MultipartSection<Body: MultipartPartBodyElement>: Sendable {
    /// Header fields for a multipart part.
    ///
    /// Contains the HTTP header fields that describe the current part, such as
    /// `Content-Disposition`, `Content-Type`, etc.
    case headerFields(HTTPFields)

    /// A chunk of body data for the current multipart part.
    ///
    /// Body data may be split across multiple chunks for streaming efficiency.
    case bodyChunk(Body)

    /// A multipart boundary marker.
    ///
    /// - Parameter end: `true` if this is the final boundary that terminates the multipart message,
    ///   `false` if it's a boundary that separates parts.
    case boundary(end: Bool)
}
