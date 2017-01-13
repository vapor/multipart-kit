import Core

extension Parser {
    /// @see parse(_ bytes: Bytes)
    public func parse(_ bytes: BytesConvertible) throws {
        try parse(try bytes.makeBytes())
    }
    
    /// @see init(boundary: Bytes)
    public convenience init(boundary: BytesConvertible) throws {
        self.init(boundary: try boundary.makeBytes())
    }
}

extension Serializer {
    /// @see init(boundary: Bytes)
    public convenience init(boundary: BytesConvertible) throws {
        self.init(boundary: try boundary.makeBytes())
    }
}
