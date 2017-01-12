import Core

final class HeaderParser {
    enum State {
        case none
        case parsingKey(buffer: Bytes)
        case parsingValue(key: Bytes, buffer: Bytes)
        case finished(key: Bytes, value: Bytes)
    }
    
    var state: State
    
    init() {
        self.state = .none
    }
    
    func parse(_ byte: Byte) throws {
        main: switch state {
        case .none:
            if byte == .newLine {
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
