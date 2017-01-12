import Core

final class ContentDispositionParser {
    enum Key {
        case name
        case filename
        case other(Bytes)
    }
    
    enum State {
        case none
        case parsingPrefix(buffer: Bytes)
        case parsingKey(buffer: Bytes)
        case parsingValue(key: Key, buffer: Bytes)
        case finished(key: Key, value: Bytes)
    }
    
    var state: State
    
    init() {
        self.state = .none
    }
    
    func parse(_ byte: Byte) {
        main: switch state {
        case .none:
            state = .parsingPrefix(buffer: [byte])
        case .parsingPrefix(var buffer):
            if byte == .semicolon && buffer == "form-data".bytes {
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
                case "name".bytes:
                    state = .parsingValue(key: .name, buffer: [])
                case "filename".bytes:
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
