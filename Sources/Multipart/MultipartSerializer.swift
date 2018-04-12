/// Serializes `MultipartForm`s to `Data`.
///
/// See `MultipartParser` for more information about the multipart encoding.
public final class MultipartSerializer {
    /// Creates a new `MultipartSerializer`.
    public init() { }
    
    /// Serializes the `MultipartForm` to data.
    ///
    ///     let data = try MultipartSerializer().serialize(parts: [part], boundary: "123")
    ///     print(data) // multipart-encoded
    ///
    /// - parameters:
    ///     - parts: One or more `MultipartPart`s to serialize into `Data`.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    /// - throws: Any errors that may occur during serialization.
    /// - returns: `multipart`-encoded `Data`.
    public func serialize(parts: [MultipartPart], boundary: LosslessDataConvertible) throws -> Data {
        var body = Data()
        var reserved = 0
        
        for part in parts {
            reserved += part.data.count
        }
        
        body.reserveCapacity(reserved + 512)
        let boundary =  [.hyphen, .hyphen] + boundary.convertToData()
        
        for part in parts {
            body.append(contentsOf: boundary)
            body.append(contentsOf: [.carriageReturn, .newLine])

            for (key, val) in part.headers {
                body.append(Data(key.description.utf8))
                body.append(contentsOf: [.colon, .space])
                body.append(Data(val.utf8))
                body.append(contentsOf: [.carriageReturn, .newLine])
            }
            body.append(contentsOf: [.carriageReturn, .newLine])
            
            body.append(part.data)
            body.append(contentsOf: [.carriageReturn, .newLine])
        }
        
        body.append(contentsOf: boundary)
        body.append(contentsOf: [.hyphen, .hyphen, .carriageReturn, .newLine])
        
        return body
    }
}
