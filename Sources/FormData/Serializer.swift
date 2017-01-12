import Core
import Multipart

public final class Serializer {
    public let boundary: Bytes
    
    public let multipartSerializer: Multipart.Serializer
    
    public init(boundary: Bytes) {
        self.boundary = boundary
        multipartSerializer = Multipart.Serializer(boundary: boundary)
    }
    
    public enum Error: Swift.Error {
        case partsAlreadySerialized
        case epilogueAlreadySerialized
    }
    
    private var partsSerialized = false
    private var epilogueSerialized = false

    public func serialize(_ field: Field) throws {
        var part = field.part
        
        var contentDisposition = "form-data; name=\"\(field.name)\""
        
        if let filename = field.filename {
            contentDisposition += "; filename=\"\(filename)\""
        }
        
        part.headers["Content-Disposition"] = contentDisposition
        try multipartSerializer.serialize(part)
    }

}
