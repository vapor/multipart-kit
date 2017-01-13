import Core

/**
    Parses headers from the top of an HTTP-style message.
 
    Pass a stream of bytes into the parser by continually calling `parse()`.
*/
final class HeaderParser {
    // An enum representing all possible states the parser can be in.
    enum State {
        case none
        case parsingKey(buffer: Bytes)
        case parsingValue(key: Bytes, buffer: Bytes)
        case finished(key: Bytes, value: Bytes)
    }
    
    // The parser must maintain its state in memory.
    var state: State
    
    // Create a new header parser.
    init() {
        self.state = .none
    }
    
    /**
        Parse a stream of bytes by iterating over each byte
        and calling `parse()`.

        After each byte, check the `state` of the header parser.
        - finished: a full header has been found, hold onto the key and value.
        - parsingKey/Value: the parser is currently gathering the header.
        - none: parser has not yet received bytes.
    */
    func parse(_ byte: Byte) throws {
        main: switch state {
        case .none:
            if byte == .newLine  {
                break main
            }
            
            state = .parsingKey(buffer: [byte])
        case .parsingKey(var buffer):
            if byte == .colon {
                state = .parsingValue(key: buffer, buffer: [])
                break main
            }
            
            buffer.append(byte)
            state = .parsingKey(buffer: buffer)
        case .parsingValue(let key, var buffer):
            if byte == .newLine {
                state = .finished(key: key, value: buffer)
                break main
            }
            
            buffer.append(byte)
            state = .parsingValue(key: key, buffer: buffer)
        case .finished:
            if byte == .newLine {
                state = .none
                break main
            }
            
            state = .parsingKey(buffer: [byte])
        }
    }
}
