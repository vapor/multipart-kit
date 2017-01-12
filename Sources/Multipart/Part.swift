import Core
import HTTP

/**
    A single Multipart part with 0 or more
    headers and a body.
*/
public struct Part {
    public var headers: [HeaderKey: String]
    public var body: Bytes
    
    /// Create a new Part.
    public init(headers: [HeaderKey: String], body: Bytes) {
        self.headers = headers
        self.body = body
    }
}
