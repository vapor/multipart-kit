public import HTTPTypes

// Internal serialization helpers shared by the `MultipartWriter` default implementations.
extension RangeReplaceableCollection<UInt8> {
    /// Appends a multipart boundary line: `--boundary\r\n`, or `--boundary--\r\n` when `end` is true.
    /// Returns the number of bytes appended.
    @inlinable
    @discardableResult
    mutating func appendBoundary(_ boundary: String, end: Bool) -> Int {
        let countBefore = self.count
        self.append(contentsOf: Array.twoHyphens)
        self.append(contentsOf: boundary.utf8)
        if end {
            self.append(contentsOf: Array.twoHyphens)
        }
        self.append(contentsOf: Array.crlf)
        return self.count - countBefore
    }

    /// Appends a header block: one `Name: value\r\n` line per field, followed by the
    /// empty line that terminates the block. Returns the number of bytes appended.
    @inlinable
    @discardableResult
    mutating func appendHeaders(_ httpFields: HTTPFields) -> Int {
        let countBefore = self.count
        for field in httpFields {
            self.append(contentsOf: field.name.rawName.utf8)
            self.append(contentsOf: Array.colonSpace)
            self.append(contentsOf: field.value.utf8)
            self.append(contentsOf: Array.crlf)
        }
        self.append(contentsOf: Array.crlf)
        return self.count - countBefore
    }
}
