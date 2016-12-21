import Core

public struct Part {
    public var headers: [String: String]
    public var body: Bytes
}

public final class Parser {
	public let boundary: Bytes
    
    public typealias PartCallback = (Part) -> ()
    public var onPart: PartCallback?
    
    public typealias PreambleCallback = (Bytes) -> ()
    public var onPreamble: PreambleCallback?
    
    public typealias EpilogueCallback = (Bytes) -> ()
    public var onEpilogue: EpilogueCallback?
    
    private enum PartState {
        case headers
        case body
    }
    
    public enum Error: Swift.Error {
        case hasAlreadyFinished
    }
    
    private enum State {
        case preamble(
            bodyEndIndex: Int
        )
        case part(
            state: PartState,
            headers: [String: String],
            bodyEndIndex: Int
        )
        case epilogue
    }
    
    private var state: State
    
    private var boundaryParser: BoundaryParser
    
    private var headerParser: HeaderParser

	public init(boundary: Bytes) {
		self.boundary = boundary
        state = .preamble(bodyEndIndex: 0)
        
        boundaryParser = BoundaryParser(boundary: boundary)
        headerParser = HeaderParser()
        
        buffer = []
        hasFinished = false
	}
    
    public convenience init(boundary: String) {
        self.init(boundary: boundary.bytes)
    }
    
    private var buffer: Bytes
    
    public func parse(_ bytes: Bytes) throws {
        buffer += bytes
        
        var i = bytes.makeIterator()
        while let byte = i.next() {
            try parse(byte)
        }
    }
    
    public func parse(_ byte: Byte) throws {
        guard !hasFinished else {
            throw Error.hasAlreadyFinished
        }
        
        switch state {
        case .preamble(let bodyEndIndex):
            try boundaryParser.parse(byte)
            switch boundaryParser.state {
            case .none:
                state = .preamble(bodyEndIndex: bodyEndIndex + 1)
            case .parsing:
                break
            case .invalid(let failed):
                state = .preamble(bodyEndIndex: bodyEndIndex + failed.count)
            case .finished(let boundarySize, let closing):
                if closing {
                    state = .epilogue
                } else {
                    state = .part(state: .headers, headers: [:], bodyEndIndex: 0)
                }
                
                let body = Array(buffer[0..<bodyEndIndex])
                
                let pos = bodyEndIndex + boundarySize
                buffer = Array(buffer[pos..<buffer.count])
                
                onPreamble?(body)
            }
        case .part(let partState, var headers, let bodyEndIndex):
            switch partState {
            case .headers:
                try headerParser.parse(byte)
                switch headerParser.state {
                case .parsingKey:
                    break
                case .parsingValue:
                    break
                case .finished(let key, let value):
                    headers[key.trimmed([.space]).string] = value.trimmed([.space]).string
                    
                    let pos = key.count + 1 + value.count + 1
                    buffer = Array(buffer[pos..<buffer.count])
                    
                    state = .part(
                        state: .headers,
                        headers: headers,
                        bodyEndIndex: 0
                    )
                case .none:
                    buffer = Array(buffer[1..<buffer.count])
                    
                    state = .part(
                        state: .body,
                        headers: headers,
                        bodyEndIndex: 0
                    )
                }
            case .body:
                try boundaryParser.parse(byte)
                switch boundaryParser.state {
                case .none:
                    state = .part(
                        state: .body,
                        headers: headers,
                        bodyEndIndex: bodyEndIndex + 1
                    )
                case .parsing:
                    break
                case .invalid(let failed):
                    state = .part(
                        state: .body,
                        headers: headers,
                        bodyEndIndex: bodyEndIndex + failed.count
                    )
                case .finished(let boundarySize, let closing):
                    if closing {
                        state = .epilogue
                    } else {
                        state = .part(state: .body, headers: headers, bodyEndIndex: 0)
                    }
                    
                    let body = Array(buffer[0..<bodyEndIndex])
                    
                    let pos = bodyEndIndex + boundarySize
                    buffer = Array(buffer[pos..<buffer.count])
                    
                    let part = Part(headers: headers, body: body)
                    onPart?(part)
                }
            }
        case .epilogue:
            break
        }
    }
    
    private var hasFinished: Bool
    
    public func finish() throws {
        guard !hasFinished else {
            throw Error.hasAlreadyFinished
        }
        
        hasFinished = true
        let body = buffer
        buffer = []
        onEpilogue?(body)
    }
}

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
