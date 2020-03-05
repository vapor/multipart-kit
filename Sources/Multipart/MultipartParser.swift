import Bits

/// Parses multipart-encoded `Data` into `MultipartPart`s. Multipart encoding is a widely-used format for encoding
/// web-form data that includes rich content like files. It allows for arbitrary data to be encoded
/// in each part thanks to a unique delimiter "boundary" that is defined separately. This
/// boundary is guaranteed by the client to not appear anywhere in the data.
///
/// `multipart/form-data` is a special case of `multipart` encoding where each part contains a `Content-Disposition`
/// header and name. This is used by the `FormDataEncoder` and `FormDataDecoder` to convert `Codable` types to/from
/// multipart data.
///
/// See [Wikipedia](https://en.wikipedia.org/wiki/MIME#Multipart_messages) for more information.
///
/// Seealso `form-urlencoded` encoding where delimiter boundaries are not required.
public final class MultipartParser {
    /// Creates a new `MultipartParser`.
    public init() { }

    /// Parses `Data` into a `MultipartForm` according to the supplied boundary.
    ///
    ///     // Content-Type: multipart/form-data; boundary=123
    ///     let data = """
    ///     --123\r
    ///     \r
    ///     foo\r
    ///     --123--\r
    ///
    ///     """
    ///     let form = try MultipartParser().parse(data: data, boundary: "123")
    ///     print(form.parts.count) // 1
    ///
    /// - parameters:
    ///     - data: `multipart` encoded data to parse.
    ///     - boundary: Multipart boundary separating the parts.
    /// - throws: Any errors parsing the encoded data.
    /// - returns: `MultipartForm` containing the parsed `MultipartPart`s.
    public func parse(data: LosslessDataConvertible, boundary: LosslessDataConvertible) throws -> [MultipartPart] {
        return try _MultipartParser(data: data.convertToData(), boundary: boundary.convertToData()).parse()
    }
}

// MARK: Private

/// Internal parser implementation.
/// TODO: Move to more performant impl, such as `ByteBuffer`.
private final class _MultipartParser {
    /// The boundary between all parts
    private let boundary: Data
    
    /// A helper variable that consists of all bytes inbetween one part's body and the next part's headers
    private let fullBoundary: Data
    
    /// The multipart form data to parse
    private let data: Data
    
    /// The current position, used for parsing
    private var position: Data.Index
    
    /// The output form
    private var parts: [MultipartPart]
    
    /// Creates a new parser for a Multipart form
    init(data: Data, boundary: Data) {
        self.data = data
        self.boundary = boundary
        self.parts = []
        self.position = self.data.startIndex
        self.fullBoundary = [.carriageReturn, .newLine, .hyphen, .hyphen] + self.boundary
    }


    /// Parses the `Data` and adds it to the Multipart.
    func parse() throws -> [MultipartPart] {
        guard parts.count == 0 else {
            throw MultipartError(identifier: "multipart:multiple-parses", reason: "Multipart may only be parsed once")
        }
        
        while position < data.count {
            // require '--' + boundary + \r\n
            try require(fullBoundary.count)
            
            // assert '--'
            try assertBoundaryStartEnd()
            
            // skip '--'
            position += 2
            
            let matches = data.subdata(in: position..<(position + boundary.count)).elementsEqual(boundary)
            
            // check boundary
            guard matches else {
                throw MultipartError(identifier: "boundary", reason: "Wrong boundary")
            }
            
            // skip boundary
            position += boundary.count
            
            guard try carriageReturnNewLine() else {
                try assertBoundaryStartEnd()
                return parts
            }
            
            let headers = try readHeaders()
            try appendPart(headers: headers)
            
            // If it doesn't end in a second `\r\n`, this must be the end of the data z
            guard try carriageReturnNewLine() else {
                guard data[position] == .hyphen, data[position + 1] == .hyphen else {
                    throw MultipartError(identifier: "eof", reason: "Invalid multipart ending")
                }
                
                return parts
            }
            
            position += 2
        }
        
        return parts
    }
    /// Asserts that the position is on top of two hyphens
    private func assertBoundaryStartEnd() throws {
        guard data[position] == .hyphen, data[position + 1] == .hyphen else {
            throw MultipartError(identifier: "boundary", reason: "Invalid multipart formatting")
        }
    }

    /// Reads the headers at the current position
    private func readHeaders() throws -> [CaseInsensitiveString: String] {
        var headers: [CaseInsensitiveString: String] = [:]

        // headers
        headerScan: while position < data.count, try carriageReturnNewLine() {
            // skip \r\n
            position += 2

            // `\r\n\r\n` marks the end of headers
            if try carriageReturnNewLine() {
                position += 2
                break headerScan
            }

            // header key
            guard let key = try scanStringUntil(.colon) else {
                throw MultipartError(identifier: "multipart:invalid-header-key", reason: "Invalid multipart header key string encoding")
            }

            // skip space (': ')
            position += 2

            // header value
            guard let value = try scanStringUntil(.carriageReturn) else {
                throw MultipartError(identifier: "multipart:invalid-header-value", reason: "Invalid multipart header value string encoding")
            }

            headers[key.ci] = value
        }

        return headers
    }

    /// Parses the part data until the boundary and decodes it.
    ///
    /// Also appends the part to the Multipart
    private func appendPart(headers: [CaseInsensitiveString: String]) throws {
        // The compiler doesn't understand this will never be `nil`
        let partData = try seekUntilBoundary()

        let part = MultipartPart(data: partData, headers: headers)
        parts.append(part)
    }


    /// Parses the part data until the boundary
    private func seekUntilBoundary() throws -> Data {
        var base = position

        // Seeks to the end of this part's content
        contentSeek: while true {
            try require(fullBoundary.count, from: base)
            let matches = data.withByteBuffer { buffer in
                return fullBoundary.withUnsafeBytes { fullBounaryBytes in
                    return buffer[base] == fullBoundary[fullBoundary.startIndex]
                        && buffer[base + 1] == fullBoundary[fullBoundary.index(after: fullBoundary.startIndex)]
                        && memcmp(fullBounaryBytes, buffer.baseAddress!.advanced(by: base), fullBoundary.count) == 0
                }
            }

            // The first 2 bytes match, check if a boundary is hit
            if matches {
                defer { position = base }
                return data[position..<base]
            }

            base += 1
        }
    }

    // Scans until the trigger is found
    // Instantiates a String from the found data
    private func scanStringUntil(_ trigger: UInt8) throws -> String? {
        var offset = 0

        headerKey: while true {
            guard position + offset < data.count else {
                throw MultipartError(identifier: "multipart:eof", reason: "Unexpected end of multipart")
            }

            if data[position + offset] == trigger {
                break headerKey
            }

            offset += 1
        }

        defer {
            position = position + offset
        }

        return String(bytes: data[position..<position + offset], encoding: .utf8)
    }

    // Checks if the current position contains a `\r\n`
    private func carriageReturnNewLine() throws -> Bool {
        try require(2)

        return data[position] == .carriageReturn && data[position + 1] == .newLine
    }
    
    // Requires `n` bytes
    private func require(_ n: Int) throws {
        try self.require(n, from: position)
    }

    // Requires `n` bytes from a given base index.
    private func require(_ n: Int, from base: Data.Index) throws {
        guard base.advanced(by: n) <= data.endIndex else {
            throw MultipartError(identifier: "missingData", reason: "Invalid multipart formatting")
        }
    }
}
