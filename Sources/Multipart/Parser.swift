import Core
import HTTP

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
            headers: [HeaderKey: String],
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
                    let headerKey = HeaderKey(key.trimmed([.space]).string)
                    headers[headerKey] = value.trimmed([.space]).string
                    
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
                        state = .part(state: .headers, headers: headers, bodyEndIndex: 0)
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
    
    private var hasFinished = false
    
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
