import Core

private let crlf: Bytes = [.carriageReturn, .newLine]

/// Creates a multipart formatted array of bytes from Parts
/// suitable for an HTTP response or request body.
public final class Serializer {
    /// The multipart boundary being used.
    public let boundary: Bytes
    
    /// A callback type for handling serialized bytes.
    public typealias SerializeCallback = (Bytes) -> ()
    
    /// Called whenever bytes have been serialized.
    /// This should be set before serializing any objects.
    public var onSerialize: SerializeCallback?
    
    /// Create a new Multipart serializer.
    public init(boundary: Bytes) {
        self.boundary = boundary
    }
    
    /// Possible errors that may be encountered while serializing.
    public enum Error: Swift.Error {
        case partsAlreadySerialized
        case epilogueAlreadySerialized
    }
    
    /// Call this method to add bytes to the preamble.
    ///
    /// This is equivalent to simply prepending bytes
    /// to the beginning of the serialized data.
    ///
    /// Preamble can obviously not be serialized after
    /// parts or the epilogue have been serialized.
    public func serialize(preamble: Bytes) throws {
        guard !partsSerialized else {
            throw Error.partsAlreadySerialized
        }
        
        serialize(preamble)
    }
    
    /// This method serializes an entire Part.
    ///
    /// This may be called as many times as needed.
    ///
    /// After all Parts have been serialized,
    /// `finish()` must be called to add the closing boundary.
    ///
    /// Parts can obviously not be serialized after the
    /// epilogue has been serialized.
    public func serialize(_ part: Part) throws {
        guard !epilogueSerialized else {
            throw Error.epilogueAlreadySerialized
        }
        
        serialize([.hyphen, .hyphen])
        serialize(boundary)
        serialize(crlf)
        for (key, value) in part.headers {
            serialize(key.key.makeBytes())
            serialize(.colon)
            serialize(.space)
            serialize(value.makeBytes())
            serialize(crlf)
        }
        serialize(crlf)
        
        serialize(part.body)
        serialize(crlf)
        
        partsSerialized = true
    }
    
    /// This method serializes the closing boundary.
    ///
    /// No parts or preamble can be serialized after this
    /// method is called.
    ///
    /// This method must be called to complete the serialized data.
    public func finish(epilogue: Bytes = []) throws {
        guard !epilogueSerialized else {
            throw Error.epilogueAlreadySerialized
        }
        
        serialize([.hyphen, .hyphen])
        serialize(boundary)
        serialize([.hyphen, .hyphen])
        serialize(crlf)
        serialize(epilogue)
        
        epilogueSerialized = true
    }
    
    // MARK: Private
    
    // Private flags for detecting improper
    // sequencing of method calls
    private var partsSerialized = false
    private var epilogueSerialized = false
    
    // Private methods for passing bytes
    // to the onSerialize callback
    private func serialize(_ byte: Byte) {
        onSerialize?([byte])
    }
    private func serialize(_ bytes: Bytes) {
        onSerialize?(bytes)
    }
}
