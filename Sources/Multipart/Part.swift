import Core
import HTTP

public struct Part {
    public var headers: [HeaderKey: String]
    public var body: Bytes
    
    public init(headers: [HeaderKey: String], body: Bytes) {
        self.headers = headers
        self.body = body
    }
}
