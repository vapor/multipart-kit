import Core
import Multipart
import HTTP

/**
    Parses form-data specific elements from
    multipart data parsed by an underlying multipart
    parser.
*/
public final class Parser {
    /// The multipart boundary being used.
    public let boundary: Bytes
    
    /// The underlying multipart parser.
    /// Subscribe to preamble and epilogue events.
    public let multipartParser: Multipart.Parser
    
    /// A callback type for handling parsed form-data fields.
    public typealias FieldCallback = (Field) -> ()
    
    /// Called whenever a complete field is parsed.
    /// Relies on the multipart parser's onPart callback.
    public var onField: FieldCallback?
    
    /// Create a new Form Data parser.
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
    
    /**
        The main method for passing bytes into the parser.
     
        @see `Multipart.Parser.parse` for performance notes.
    */
    public func parse(_ bytes: Bytes) throws {
        try multipartParser.parse(bytes)
    }
}
