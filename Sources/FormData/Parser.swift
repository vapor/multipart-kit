import Core
import Multipart
import HTTP

public final class Parser {
    public let boundary: Bytes
    public let multipartParser: Multipart.Parser
    
    public typealias FieldCallback = (Field) -> ()
    public var onField: FieldCallback?
    
    public init(boundary: Bytes) {
        self.boundary = boundary
        multipartParser = Multipart.Parser(boundary: boundary)
        
        multipartParser.onPart = { part in
            if let contentDisposition = part.headers[.contentDisposition] {
                let parser = ContentDispositionParser()
                
                var name: String?
                var filename: String?
                
                for byte in contentDisposition.bytes {
                    parser.parse(byte)
                    
                    switch parser.state {
                    case .finished(let key, let value):
                        switch key {
                        case .name:
                            name = value.string
                        case .filename:
                            filename = value.string
                        case .other:
                            break
                        }
                    default:
                        break
                    }
                }
                
                if let name = name {
                    let field = Field(name: name, filename: filename, part: part)
                    self.onField?(field)
                }
                
            }
        }
    }
    
    public func parse(_ bytes: Bytes) throws {
        try multipartParser.parse(bytes)
    }
}
