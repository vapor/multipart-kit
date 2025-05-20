/// Serializes ``MultipartPart``s to some ``MultipartPartBodyElement``.
extension MultipartSerializer {
    /// Serializes some ``MultipartPart``s to some ``MultipartPartBodyElement``.
    ///
    /// ```swift
    /// let serialized: ArraySlice<UInt8> = MultipartSerializer(boundary: "123").serialize(parts: [part])
    /// ```
    ///
    /// - Parameters:
    ///   - parts: One or more ``MultipartPart``s to serialize into some ``MultipartPartBodyElement``.
    /// - Returns: some `multipart`-encoded ``MultipartPartBodyElement``.
    public func serialize(
        parts: [MultipartPart<some MultipartPartBodyElement>],
        into: Body.Type = Body.self
    ) -> Body {
        var buffer = Body()
        self.serialize(parts: parts, into: &buffer)
        return buffer
    }

    /// Serializes some ``MultipartPart``s to a buffer.
    ///
    /// ```swift
    /// var buffer = ByteBuffer().readableBytesView
    /// MultipartSerializer(boundary: "123").serialize(parts: [part], into: &buffer)
    /// ```
    ///
    /// - Parameters:
    ///   - parts: One or more ``MultipartPart``s to serialize into a buffer.
    ///   - buffer: Buffer to write to.
    /// - Note: `ByteBuffer` directly won't work because we have no dependency on NIO.
    ///   You can use `ByteBufferView` via `ByteBuffer.readableBytesView`.
    public func serialize<OutputBody: MultipartPartBodyElement>(
        parts: [MultipartPart<some MultipartPartBodyElement>],
        into buffer: inout OutputBody
    ) {
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
