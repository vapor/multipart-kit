import HTTPTypes

/// Decodes `Decodable` types from `multipart/form-data` encoded `Data`.
///
/// See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
///
/// Seealso `MultipartParser` for more information about the `multipart` encoding.
public struct FormDataDecoder<Body: MultipartPartBodyElement>: Sendable {

    /// Maximum nesting depth to allow when decoding the input.
    /// - 1 corresponds to a single value
    /// - 2 corresponds to an an object with non-nested properties or an 1 dimensional array
    /// - 3... corresponds to nested objects or multi-dimensional arrays or combinations thereof
    let nestingDepth: Int

    /// Any contextual information set by the user for decoding.
    public var userInfo: [CodingUserInfoKey: any Sendable] = [:]

    /// Creates a new `FormDataDecoder`.
    /// - Parameter nestingDepth: maximum allowed nesting depth of the decoded structure. Defaults to 8.
    public init(nestingDepth: Int = 8) {
        self.nestingDepth = nestingDepth
    }

    /// Decodes a `Decodable` item from `String` using the supplied boundary.
    ///
    ///     let foo = try FormDataDecoder().decode(Foo.self, from: "...", boundary: "123")
    ///
    /// - Parameters:
    ///   - decodable: Generic `Decodable` type.
    ///   - data: String to decode.
    ///   - boundary: Multipart boundary to used in the decoding.
    /// - Throws: Any errors decoding the model with `Codable` or parsing the data.
    /// - Returns: An instance of the decoded type `D`.
    public func decode<D: Decodable>(_ decodable: D.Type, from data: String, boundary: String) throws -> D {
        try decode(D.self, from: Array(data.utf8), boundary: boundary)
    }

    /// Decodes a `Decodable` item from `Data` using the supplied boundary.
    ///
    ///     let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "123")
    ///
    /// - Parameters:
    ///   - decodable: Generic `Decodable` type.
    ///   - data: Data to decode.
    ///   - boundary: Multipart boundary to used in the decoding.
    /// - Throws: Any errors decoding the model with `Codable` or parsing the data.
    /// - Returns: An instance of the decoded type `D`.
    public func decode<D: Decodable>(_ decodable: D.Type, from data: [UInt8], boundary: String) throws -> D {
        try decode(D.self, from: data, boundary: boundary)
    }

    /// Decodes a `Decodable` item from `Data` using the supplied boundary.
    ///
    ///     let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "123")
    ///
    /// - Parameters:
    ///   - decodable: Generic `Decodable` type.
    ///   - data: Data to decode.
    ///   - boundary: Multipart boundary to used in the decoding.
    /// - Throws: Any errors decoding the model with `Codable` or parsing the data.
    /// - Returns: An instance of the decoded type `D`.
    public func decode<D: Decodable>(_ decodable: D.Type, from buffer: Body, boundary: String) async throws
        -> D where Body.SubSequence: Equatable & Sendable
    {
        let stream = AsyncStream<Body.SubSequence> { continuation in
            let endIndex = buffer.endIndex
            var offset = buffer.startIndex
            while offset < endIndex {
                let endIndex = min(endIndex, buffer.index(offset, offsetBy: 16))
                continuation.yield(buffer[offset..<endIndex])
                offset = endIndex
            }
            continuation.finish()
        }

        let sequence = MultipartParserAsyncSequence(boundary: boundary, buffer: stream)
        var parts: [MultipartPart<ArraySlice<UInt8>>] = []
        
        var currentHeaders: HTTPFields?
        var currentBody = ArraySlice<UInt8>()
        
        for try await part in sequence {
            switch part {
            case .bodyChunk(let chunk):
                currentBody.append(contentsOf: chunk)
            case .headerFields(let field):
                if var currentHeaders {
                    currentHeaders = HTTPFields(currentHeaders + field)
                } else {
                    currentHeaders = field
                }
            case .boundary:
                if let headers = currentHeaders {
                    parts.append(MultipartPart(headerFields: headers, body: currentBody))
                }
                currentHeaders = nil
                currentBody = []
            }
        }
        
        let data = MultipartFormData<ArraySlice<UInt8>>(parts: parts, nestingDepth: nestingDepth)
        let decoder = FormDataDecoder<ArraySlice<UInt8>>.Decoder(codingPath: [], data: data, userInfo: userInfo)
        return try decoder.decode(D.self)
    }
}
