import Core

extension Parser {
    public func parse(_ bytes: BytesConvertible) throws {
        try parse(try bytes.makeBytes())
    }

    public convenience init(boundary: BytesConvertible) throws {
        self.init(boundary: try boundary.makeBytes())
    }
}

extension Serializer {
    public convenience init(boundary: BytesConvertible) throws {
        self.init(boundary: try boundary.makeBytes())
    }
}
