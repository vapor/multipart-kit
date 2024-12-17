import HTTPTypes

/// Decodes `Decodable` types from `multipart/form-data` encoded data.
///
/// See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
///
/// - Seealso: ``MultipartParser`` for more information about the `multipart` encoding.
public struct FormDataDecoder: Sendable {

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
    ///   - data: `String` to decode.
    ///   - boundary: Multipart boundary to used in the decoding.
    /// - Throws: Any errors decoding the model with `Codable` or parsing the data.
    /// - Returns: An instance of the decoded type `D`.
    public func decode<D: Decodable>(_ decodable: D.Type, from string: String, boundary: String) throws -> D {
        try decode(D.self, from: Array(string.utf8), boundary: boundary)
    }

    /// Decodes a `Decodable` item from  some``MultipartPartBodyElement`` using the supplied boundary.
    ///
    ///     let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "123")
    ///
    /// - Parameters:
    ///   - decodable: Generic `Decodable` type.
    ///   - data: some ``MultipartPartBodyElement`` to decode.
    ///   - boundary: Multipart boundary to used in the decoding.
    /// - Throws: Any errors decoding the model with `Codable` or parsing the data.
    /// - Returns: An instance of the decoded type `D`.
    public func decode<D: Decodable, Body: MultipartPartBodyElement>(
        _ decodable: D.Type,
        from buffer: Body,
        boundary: String
    )
        throws -> D where Body: RangeReplaceableCollection, Body.SubSequence: Equatable & Sendable
    {
        let parts = try MultipartParser(boundary: boundary).parse(buffer)
        let data = MultipartFormData(parts: parts, nestingDepth: nestingDepth)
        let decoder = FormDataDecoder.Decoder(codingPath: [], data: data, userInfo: userInfo)
        return try decoder.decode(D.self)
    }
}
