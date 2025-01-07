/// Serializes ``MultipartPart``s to some ``MultipartPartBodyElement``.
public struct MultipartSerializer: Sendable {
    let boundary: String

    /// Creates a new ``MultipartSerializer``.
    public init(boundary: String) {
        self.boundary = boundary
    }

    /// Serializes some ``MultipartPart``s to some ``MultipartPartBodyElement``.
    ///
    ///     let serialized: ArraySlice<UInt8> = try MultipartSerializer(boundary: "123").serialize(parts: [part])
    ///
    /// - Parameters:
    ///   - parts: One or more ``MultipartPart``s to serialize into some ``MultipartPartBodyElement``.
    /// - Throws: Any errors that may occur during serialization.
    /// - Returns: some `multipart`-encoded ``MultipartPartBodyElement``.
    public func serialize<Body: MultipartPartBodyElement>(parts: [MultipartPart<some MultipartPartBodyElement>]) throws -> Body
    where Body: RangeReplaceableCollection {
        var buffer = Body()
        try self.serialize(parts: parts, into: &buffer)
        return buffer
    }

    /// Serializes some ``MultipartPartBodyElement`` to a `String`.
    ///
    ///     let serialized: String = try MultipartSerializer(boundary: "123").serialize(parts: [part])
    ///
    /// - Parameters:
    ///   - parts: One or more ``MultipartPart``s to serialize into some ``MultipartPartBodyElement``.
    /// - Throws: Any errors that may occur during serialization.
    /// - Returns: a `multipart`-encoded `String`.
    public func serialize<Body: MultipartPartBodyElement>(parts: [MultipartPart<Body>]) throws -> String
    where Body: RangeReplaceableCollection {
        var buffer = Body()
        try self.serialize(parts: parts, into: &buffer)
        return String(decoding: buffer, as: UTF8.self)
    }

    /// Serializes some ``MultipartPart``s to a buffer.
    ///
    ///     var buffer = ByteBuffer().readableBytesView
    ///     try MultipartSerializer(boundary: "123").serialize(parts: [part], into: &buffer)
    ///
    /// - Parameters:
    ///   - parts: One or more ``MultipartPart``s to serialize into a buffer.
    ///   - buffer: Buffer to write to.
    /// - Throws: Any errors that may occur during serialization.
    /// - Note: `ByteBuffer` directly won't work because we have no dependency on NIO.
    ///   You can use `ByteBufferView` via `ByteBuffer.readableBytesView`.
    public func serialize<OutputBody: MultipartPartBodyElement>(
        parts: [MultipartPart<some MultipartPartBodyElement>],
        into buffer: inout OutputBody
    ) throws where OutputBody: RangeReplaceableCollection {
        for part in parts {
            buffer.append(.hyphen)
            buffer.append(.hyphen)
            buffer.append(contentsOf: boundary.utf8)
            buffer.append(contentsOf: ArraySlice<UInt8>.crlf)
            for field in part.headerFields {
                buffer.append(contentsOf: field.description.utf8)
                buffer.append(contentsOf: ArraySlice<UInt8>.crlf)
            }
            buffer.append(contentsOf: ArraySlice<UInt8>.crlf)
            buffer.append(contentsOf: part.body)
            buffer.append(contentsOf: ArraySlice<UInt8>.crlf)
        }
        buffer.append(.hyphen)
        buffer.append(.hyphen)
        buffer.append(contentsOf: boundary.utf8)
        buffer.append(.hyphen)
        buffer.append(.hyphen)
        buffer.append(contentsOf: ArraySlice<UInt8>.crlf)
    }
}
