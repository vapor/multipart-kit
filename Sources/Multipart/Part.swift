import Core
import HTTP

public struct Part {
    public var headers: [HeaderKey: String]
    public var body: Bytes
}
