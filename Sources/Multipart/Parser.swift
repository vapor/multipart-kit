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
    
    public typealias EpilogueUpdateCallback = (Bytes) -> ()
    public var onEpilogueUpdate: EpilogueUpdateCallback?
    
    private enum PartState {
        case headers
        case body
    }
    
    private enum State {
        case preamble(body: Bytes)
        case part(
            state: PartState,
            headers: [String: String],
            body: Bytes
        )
        case epilogue(body: Bytes)
    }
    private var state: State

	public init(boundary: Bytes) {
		self.boundary = boundary
        state = .preamble(body: [])
        boundaryState = .none
	}
    
    public convenience init(boundary: String) {
        self.init(boundary: boundary.bytes)
    }
    
    public func parse(_ bytes: Bytes) {
        var i = bytes.makeIterator()
        while let byte = i.next() {
            parse(byte)
        }
    }
    
    public func parse(_ byte: Byte) {
        switch state {
        case .preamble(var body):
            
            parseBoundary(byte)
            switch boundaryState {
            case .none:
                body.append(byte)
                state = .preamble(body: body)
            case .parsing:
                break
            case .invalid(let failed):
                body += failed
                state = .preamble(body: body)
            case .detected(let closing):
                if closing {
                    state = .epilogue(body: [])
                } else {
                    state = .part(state: .headers, headers: [:], body: [])
                }
                onPreamble?(body)
            }
        case .part(_, let headers, var body):
            parseBoundary(byte)
            switch boundaryState {
            case .none:
                body.append(byte)
                state = .part(state: .headers, headers: [:], body: body)
            case .parsing:
                break
            case .invalid(let failed):
                body += failed
                state = .part(state: .headers, headers: [:], body: body)
            case .detected(let closing):
                if closing {
                    state = .epilogue(body: [])
                } else {
                    state = .part(state: .headers, headers: [:], body: [])
                }
                let part = Part(headers: headers, body: body)
                onPart?(part)
            }
        case .epilogue(var body):
            body.append(byte)
            state = .epilogue(body: body)
            onEpilogueUpdate?(body)
        }
    }
    
    private enum BoundaryState {
        case none
        case parsing(buffer: Bytes, trailingHyphenCount: Int)
        case invalid(failed: Bytes)
        case detected(closing: Bool)
    }
    
    private var boundaryState: BoundaryState
    
    private func parseBoundary(_ byte: Byte) {
        main: switch boundaryState {
        case .none:
            if byte == .hyphen {
                boundaryState = .parsing(buffer: [byte], trailingHyphenCount: 0)
                break main
            }
        case .parsing(let buffer, let trailingHyphenCount):
            let match = [.hyphen, .hyphen] + boundary
            
            if
                (buffer.count <= 1 && byte == .hyphen) ||
                (buffer.count > 1 && buffer.count < match.count)
            {
                boundaryState = .parsing(buffer: buffer + [byte], trailingHyphenCount: trailingHyphenCount)
                break main
            } else {
                if buffer == match {
                    if byte == .newLine {
                        switch trailingHyphenCount {
                        case 0:
                            boundaryState = .detected(closing: false)
                            break main
                        case 2:
                            boundaryState = .detected(closing: true)
                            break main
                        default:
                            break
                        }
                    } else if byte == .hyphen {
                        boundaryState = .parsing(buffer: buffer, trailingHyphenCount: trailingHyphenCount + 1)
                        break main
                    }
                }
            }
        
            boundaryState = .invalid(failed: buffer + [byte])
        case .invalid:
            boundaryState = .none
        case .detected:
            boundaryState = .none
        }
    }
}
