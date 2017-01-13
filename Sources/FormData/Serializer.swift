import Core
import Multipart

/**
    Creates a multipart/form-data formatted array of bytes from Fields
    suitable for an HTTP response or request body.
 */
public final class Serializer {
    /// The multipart boundary being used.
    public let boundary: Bytes
    
    /// The underlying multipart serializer.
    /// Use to serialize preamble and epilogue.
    public let multipartSerializer: Multipart.Serializer
    
    public init(boundary: Bytes) {
        self.boundary = boundary
        multipartSerializer = Multipart.Serializer(boundary: boundary)
    }
    
    /**
        This method serializes an entire Field.

        This may be called as many times as needed.

        After all Field have been serialized,
        `finish()` must be called on the multipart serializer
        to add the closing boundary.

        Fields can obviously not be serialized after the
        epilogue has been serialized.
    */
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
