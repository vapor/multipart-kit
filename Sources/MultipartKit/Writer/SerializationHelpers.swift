public import HTTPTypes

// Internal serialization helpers shared by the `MultipartWriter` default implementations.
extension RangeReplaceableCollection<UInt8> {
    /// Appends a multipart boundary line: `--boundary\r\n`, or `--boundary--\r\n` when `end` is true.
    @inlinable
    mutating func appendBoundary(_ boundary: String, end: Bool) {
        self.append(contentsOf: ArraySlice.twoHyphens)
        self.append(contentsOf: boundary.utf8)
        if end {
            self.append(contentsOf: ArraySlice.twoHyphens)
        }
        self.append(contentsOf: ArraySlice.crlf)
    }

    /// Appends a header block: one `Name: value\r\n` line per field, followed by the
    /// empty line that terminates the block.
    @inlinable
    mutating func appendHeaders(_ httpFields: HTTPFields) {
        for field in httpFields {
            self.append(contentsOf: field.name.rawName.utf8)
            self.append(contentsOf: ArraySlice.colonSpace)
            self.append(contentsOf: field.value.utf8)
            self.append(contentsOf: ArraySlice.crlf)
        }
        self.append(contentsOf: ArraySlice.crlf)
    }
}
