import HTTPTypes

extension MultipartParser {
    /// Synchronously parse the multipart data into an array of ``MultipartPart``.
    ///
    /// The whole message must be present in `data`. Every part is held in memory at once, so
    /// prefer ``StreamingMultipartParserAsyncSequence`` for large messages such as file uploads.
    ///
    /// - Parameter data: The complete multipart message.
    /// - Throws: ``MultipartParserError`` if the message is malformed, or
    ///   ``MultipartParserError/unexpectedEndOfFile`` if it is incomplete.
    /// - Returns: The parts of the message, in the order they appeared.
    @_specialize(where Body == ArraySlice<UInt8>)
    public func parse<Body: MultipartPartBodyElement>(_ data: Body) throws(MultipartParserError) -> [MultipartPart<Body>] {
        // Arrays and slices can be shared with the parser instead of copied.
        try self.parts(in: Self.bytes(of: data))
    }

    static func bytes(of data: some MultipartPartBodyElement) -> ArraySlice<UInt8> {
        switch data {
        case let slice as ArraySlice<UInt8>: slice
        case let array as [UInt8]: array[...]
        default: ArraySlice(data)
        }
    }

    /// Synchronously parse the multipart data into an array of ``MultipartPart``.
    ///
    /// The whole message must be present in `data`. The bytes are copied once into the parser.
    ///
    /// - Parameter data: The complete multipart message.
    /// - Throws: ``MultipartParserError`` if the message is malformed, or
    ///   ``MultipartParserError/unexpectedEndOfFile`` if it is incomplete.
    /// - Returns: The parts of the message, in the order they appeared.
    public func parse<Body: MultipartPartBodyElement>(
        _ data: Span<UInt8>,
        as: Body.Type = Body.self
    ) throws(MultipartParserError) -> [MultipartPart<Body>] {
        try self.parts(in: data.withUnsafeBufferPointer { unsafe ArraySlice($0) })
    }

    func parts<Body: MultipartPartBodyElement>(
        in bytes: ArraySlice<UInt8>,
        as: Body.Type = Body.self
    ) throws(MultipartParserError) -> [MultipartPart<Body>] {
        var output: [MultipartPart<Body>] = []
        var parser = self

        var currentHeaders = HTTPFields()
        var currentBody = ArraySlice<UInt8>()

        // Append all data at once since this is synchronous
        parser.append(buffer: bytes)

        while true {
            switch parser.read() {
            case .success(let section?):
                switch section {
                case .headerFields(let newFields):
                    currentHeaders.append(contentsOf: newFields)

                case .bodyChunk(let chunk):
                    if currentBody.isEmpty {
                        currentBody = chunk
                    } else {
                        currentBody.append(contentsOf: chunk)
                    }

                case .boundary:
                    if !currentHeaders.isEmpty {
                        let body = currentBody as? Body ?? Body(currentBody)
                        output.append(MultipartPart(headerFields: currentHeaders, body: body))
                        // Reset for next part
                        currentHeaders = HTTPFields()
                        currentBody = ArraySlice()
                    }
                }

            case .success(nil):
                continue

            case .needMoreData:
                // In synchronous parsing with all data provided upfront,
                // needing more data indicates an incomplete/corrupted message
                throw .unexpectedEndOfFile

            case .error(let error):
                throw error

            case .finished:
                // Add final part if exists
                if !currentHeaders.isEmpty {
                    let body = currentBody as? Body ?? Body(currentBody)
                    output.append(MultipartPart(headerFields: currentHeaders, body: body))
                    currentHeaders = HTTPFields()
                    currentBody = ArraySlice()
                }
                return output
            }
        }
    }
}
