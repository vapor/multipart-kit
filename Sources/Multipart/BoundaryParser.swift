import Core

final class BoundaryParser {
    enum State {
        case none
        case parsing(buffer: Bytes, trailingHyphenCount: Int)
        case invalid(failed: Bytes)
        case finished(boundarySize: Int, closing: Bool)
    }
    
    let boundary: Bytes
    
    var state: State
    
    init(boundary: Bytes) {
        self.boundary = boundary
        self.state = .none
    }
    
    
    func parse(_ byte: Byte) throws {
        main: switch state {
        case .none:
            if byte == .hyphen {
                state = .parsing(buffer: [byte], trailingHyphenCount: 0)
                break main
            }
        case .parsing(let buffer, let trailingHyphenCount):
            let match = [.hyphen, .hyphen] + boundary
            
            if
                (buffer.count <= 1 && byte == .hyphen) ||
                    (buffer.count > 1 && buffer.count < match.count)
            {
                state = .parsing(buffer: buffer + [byte], trailingHyphenCount: trailingHyphenCount)
                break main
            } else {
                if buffer == match {
                    if byte == .newLine {
                        switch trailingHyphenCount {
                        case 0:
                            // --boundary + \n
                            let size = match.count + 1
                            state = .finished(
                                boundarySize: size,
                                closing: false
                            )
                            break main
                        case 2:
                            // --boundary + -- + \n
                            let size = match.count + 2 + 1
                            state = .finished(
                                boundarySize: size,
                                closing: true
                            )
                            break main
                        default:
                            break
                        }
                    } else if byte == .hyphen {
                        state = .parsing(buffer: buffer, trailingHyphenCount: trailingHyphenCount + 1)
                        break main
                    }
                }
            }
            
            state = .invalid(failed: buffer + [byte])
        case .invalid:
            state = .none
        case .finished:
            state = .none
        }
    }
}
