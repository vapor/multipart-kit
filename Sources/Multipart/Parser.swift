import Core
import HTTP
import Foundation

/// Parses preamble, Parts, and epilogue from a Multipart
/// formatted sequence of bytes likely from an HTTP request or response.
public final class Parser {
    /// The multipart boundary being used.
	public let boundary: Bytes
    
    /// A callback type for handling parsed Part structs.
    public typealias PartCallback = (Part) -> ()
    
    /// Called whenever a complete Part has been parsed.
    public var onPart: PartCallback?
    
    /// A callback type for handling the parsed preamble.
    public typealias PreambleCallback = (Bytes) -> ()

    /// Called once after the preamble has been parsed.
    public var onPreamble: PreambleCallback?
    
    /// A callback type for handling the parsed epilogue.
    public typealias EpilogueCallback = (Bytes) -> ()

    /// Called once after the epilogue has been parsed.
    public var onEpilogue: EpilogueCallback?
    
    /// Possible errors that may be encountered while parsing.
    public enum Error: Swift.Error {
        case hasAlreadyFinished
        case invalidBoundary
    }
    
    /// An enum representing all possible states of the parser.
    private enum State {
        case preamble
        case part(
            state: PartState,
            headers: [HeaderKey: String],
            /// The start index of this part's *body* in `buffer`
            /// Set to 0 during header parsing
            bodyStartIndex: ArraySlice<Byte>.Index
        )
        case epilogue
    }
    
    /// An enum representing all possible sub-states State.part
    private enum PartState {
        case headers
        case body
    }

    private var cursor: ArraySlice<Byte>.Index

    /// The parser must maintain its state in memory.
    private var state: State
    
    // A specialized parser for finding boundaries.
    private var boundaryParser: BoundaryParser
    
    // A specialized parser for gathering headers.
    private var headerParser: HeaderParser

    /// Create a new multipart parser.
	public init(boundary: Bytes) {
		self.boundary = boundary
        buffer = []
        cursor = buffer.startIndex
        state = .preamble
        
        boundaryParser = BoundaryParser(boundary: boundary)
        headerParser = HeaderParser()
	}
    
    /// Extracts the boundary from a multipart Content-Type header
    public static func extractBoundary(contentType: BytesConvertible) throws -> Bytes {
        let contentTypeString = try contentType.makeBytes().makeString()
		guard let boundaryEndIndex = contentTypeString.range(of: "boundary=")?.upperBound else { throw Error.invalidBoundary }
		
		var boundaryRange = boundaryEndIndex ..< contentTypeString.endIndex
        #if swift(>=4)
        let boundaryString = String(contentTypeString[boundaryRange])
        #else
        let boundaryString = String(contentTypeString[boundaryRange]) ?? ""
        #endif
		if boundaryString.hasPrefix("\"") {
			if !boundaryString.hasSuffix("\"") {
                throw Error.invalidBoundary
            }
			
			boundaryRange = contentTypeString.index(boundaryRange.lowerBound, offsetBy: 1) ..< contentTypeString.index(boundaryRange.upperBound, offsetBy: -1) 
		}
		
		return String(contentTypeString[boundaryRange]).makeBytes()
    }
    
    /// Create a new multipart parser from a 
    /// Content-Type header value.
    public convenience init(contentType: BytesConvertible) throws {
        let boundary = try Parser.extractBoundary(contentType: contentType)
        self.init(boundary: boundary)
    }
    
    // A buffer for the bytes that have been parsed.
    // This allows for a reduction in the number of copies
    // needed for each step as only indices into this array
    // need to be passed around.
    private var buffer: ArraySlice<Byte>
    
    /// The main method for passing bytes into the parser.
    ///
    /// A copy is performed to move the bytes passed into
    /// the parser's internal memory. The bytes are then
    /// iterated over one by one.
    ///
    /// Callbacks will be made as the preamble, Parts, and
    /// epilogue are discovered.
    public func parse(_ bytes: Bytes) throws {
        buffer += bytes

        var i = bytes.makeIterator()
        while let byte = i.next() {
            try parse(byte)
        }
    }
    
    /// Call this method when there are no bytes
    /// left to parse.
    ///
    /// This will trigger any parsed epilogue bytes
    /// to be returned.
    public func finish() throws {
        guard !hasFinished else {
            throw Error.hasAlreadyFinished
        }
        
        hasFinished = true
        
        let raw = Array(buffer[cursor..<buffer.endIndex])
        let body = Array(raw.trimmed([.newLine, .carriageReturn]))

        buffer = []
        onEpilogue?(body)
    }
    
    // Parses an individual byte that is 
    // known to be in the internal buffer.
    private func parse(_ byte: Byte) throws {
        guard !hasFinished else {
            throw Error.hasAlreadyFinished
        }

        switch state {
        case .preamble:
            try boundaryParser.parse(byte)
            switch boundaryParser.state {
            case .none:
                state = .preamble
                cursor += 1
            case .parsing:
                break
            case .invalid(let failed):
                state = .preamble
                cursor += failed.count
            case .finished(let boundarySize, let closing):
                if closing {
                    state = .epilogue
                } else {
                    state = .part(state: .headers, headers: [:], bodyStartIndex: 0)
                }
                
                let body = Array(buffer[buffer.startIndex..<cursor])
                
                //                       newline
                cursor += boundarySize + 1

                // Can be > endIndex because of newline
                if cursor > buffer.endIndex {
                    cursor = buffer.endIndex
                }

                onPreamble?(body)
            }
        case .part(let partState, var headers, let bodyStartIndex):
            switch partState {
            case .headers:
                try headerParser.parse(byte)
                switch headerParser.state {
                case .parsingKey:
                    break
                case .parsingValue:
                    break
                case .finished(let key, let value):
                    let headerKey = HeaderKey(key.trimmed([.space]).makeString())
                    headers[headerKey] = value.trimmed([.space]).makeString()
                    
                    //                    colon             newline
                    cursor += key.count + 1 + value.count + 2
                    
                    state = .part(
                        state: .headers,
                        headers: headers,
                        bodyStartIndex: cursor
                    )
                case .none:
                    //        crlf
                    cursor += 2

                    state = .part(
                        state: .body,
                        headers: headers,
                        bodyStartIndex: cursor
                    )
                }
            case .body:
                try boundaryParser.parse(byte)
                switch boundaryParser.state {
                case .none:
                    state = .part(
                        state: .body,
                        headers: headers,
                        bodyStartIndex: bodyStartIndex
                    )
                    cursor += 1
                case .parsing:
                    break
                case .invalid(let failed):
                    state = .part(
                        state: .body,
                        headers: headers,
                        bodyStartIndex: bodyStartIndex
                    )
                    cursor += failed.count
                case .finished(let boundarySize, let closing):
                    if closing {
                        state = .epilogue
                    } else {
                        state = .part(state: .headers, headers: headers, bodyStartIndex: 0)
                    }
                    
                    let raw = Array(buffer[bodyStartIndex..<cursor])
                    let body = Array(raw.trimmed([.newLine, .carriageReturn]))

                    //                       newline
                    cursor += boundarySize + 1

                    if cursor > buffer.endIndex {
                        cursor = buffer.endIndex
                    }

                    let part = Part(headers: headers, body: body)
                    onPart?(part)
                }
            }
        case .epilogue:
            break
        }
    }
    
    // Private flag for tracking whether `finish()`
    // has been called.
    private var hasFinished = false
}
