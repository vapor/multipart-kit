import Core

/**
    Parses `Content-Disposition` header values for
    form-data encoded messages.
*/
final class ContentDispositionParser {
    /// Key types expected in the content disposition.
    enum Key {
        case name
        case filename
        case other(Bytes)
    }
    
    /// All possible states for the parser.
    enum State {
        case none
        case parsingPrefix(buffer: Bytes)
        case parsingKey(buffer: Bytes)
        case parsingValue(key: Key, buffer: Bytes)
        case finished(key: Key, value: Bytes)
    }
    
    // The parser must maintain its state in memory.
    var state: State
    
    // Create a new content disposition parser.
    init() {
        self.state = .none
    }
    
    /**
        Parse a stream of bytes by iterating over each byte
        and calling `parse()`.

        After each byte, check the `state` of the header parser.
        - finished: a full key/value pair has been found.
        - parsingPrefix/Key/Value: the parser is currently parsing values.
        - none: parser has not yet received bytes.
    */
    func parse(_ byte: Byte) {
        main: switch state {
        case .none:
            state = .parsingPrefix(buffer: [byte])
        case .parsingPrefix(var buffer):
            if byte == .semicolon && buffer == "form-data".makeBytes() {
                state = .parsingKey(buffer: [])
                break main
            }
            
            buffer.append(byte)
            state = .parsingPrefix(buffer: buffer)
        case .parsingKey(var buffer):
            if byte == .space {
                break main
            }
            
            if byte == .equals {
                switch buffer {
                case "name".makeBytes():
                    state = .parsingValue(key: .name, buffer: [])
                case "filename".makeBytes():
                    state = .parsingValue(key: .filename, buffer: [])
                default:
                    state = .parsingValue(key: .other(buffer), buffer: [])
                }
                
                break main
            }
            
            buffer.append(byte)
            state = .parsingKey(buffer: buffer)
        case .parsingValue(let key, var buffer):
            if byte == .quote {
                if buffer.count > 0 {
                    state = .finished(key: key, value: buffer)
                    
                }
                break main
            }
            
            buffer.append(byte)
            state = .parsingValue(key: key, buffer: buffer)
        case .finished:
            state = .parsingKey(buffer: [])
        }
    }
}
