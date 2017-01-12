import Core

public final class Serializer {
    public let boundary: Bytes
    
    public typealias SerializeCallback = (Bytes) -> ()
    public var onSerialize: SerializeCallback?
    
    public init(boundary: Bytes) {
        self.boundary = boundary
    }
    
    public enum Error: Swift.Error {
        case partsAlreadySerialized
        case epilogueAlreadySerialized
    }
    
    private var partsSerialized = false
    private var epilogueSerialized = false
    
    private func serialize(_ byte: Byte) {
        onSerialize?([byte])
    }
    
    private func serialize(_ bytes: Bytes) {
        onSerialize?(bytes)
    }
    
    public func serialize(preamble: Bytes) throws {
        guard !partsSerialized else {
            throw Error.partsAlreadySerialized
        }
        
        serialize(preamble)
    }
    
    public func serialize(_ part: Part) throws {
        guard !epilogueSerialized else {
            throw Error.epilogueAlreadySerialized
        }
        
        serialize([.hyphen, .hyphen])
        serialize(boundary)
        serialize(.newLine)
        for (key, value) in part.headers {
            serialize(key.key.bytes)
            serialize(.colon)
            serialize(.space)
            serialize(value.bytes)
            serialize(.newLine)
        }
        serialize(.newLine)
        
        serialize(part.body)
        serialize(.newLine)
        
        partsSerialized = true
    }
    
    public func finish(epilogue: Bytes = []) throws {
        guard !epilogueSerialized else {
            throw Error.epilogueAlreadySerialized
        }
        
        serialize([.hyphen, .hyphen])
        serialize(boundary)
        serialize([.hyphen, .hyphen])
        serialize(.newLine)
        serialize(epilogue)
        
        epilogueSerialized = true
    }
}
