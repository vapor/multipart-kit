import Core

/**
    Attempts to parse a supplied boundary out of a stream of bytes.
 
    Pass a stream of bytes into to the parser by continually calling `parse()`.
*/
final class BoundaryParser {
    // An enum representing all possible states the parser can be in.
    enum State {
        case none
        case parsing(buffer: Bytes, trailingHyphenCount: Int)
        case invalid(failed: Bytes)
        case finished(boundarySize: Int, closing: Bool)
    }
    
    // The boundary the parser is looking for.
    let boundary: Bytes
    
    // The parser must maintain its state in memory.
    var state: State
    
    // Create a new boundary parser.
    init(boundary: Bytes) {
        self.boundary = boundary
        self.state = .none
    }
    
    /**
        Parse a stream of bytes by iterating over each byte
        and calling `parse()`.
     
        After each byte, check the `state` of the boundary parser.
        - finished: a boundary was found!
        - parsing: the parser may have found a boundary, do not buffer bytes.
        - invalid: what looked like a boundary is not. reclaim the skipped bytes.
        - none: no boundary detected, continue buffering the bytes.
    */
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
