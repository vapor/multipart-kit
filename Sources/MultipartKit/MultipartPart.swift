/// A single part of a `multipart`-encoded message.
public struct MultipartPart: Equatable {
    /// The part's headers.
    public var headers: [String: String]

    /// The part's raw data.
    public var body: [UInt8]
    
    /// Gets or sets the `name` attribute from the part's `"Content-Disposition"` header.
    public var name: String? {
        get { self.contentDispositionParameter("name") }
        set { self.setContentDispositionParameter("name", to: newValue) }
    }

    /// Gets or sets the part's `"Content-Disposition"` header.
    public var contentDisposition: (String, [String: String])? {
        get {
            self.headers["Content-Disposition"].flatMap {
                return HeaderValue.parse($0)
            }.flatMap { value in
                return (value.value, value.parameters)
            }
        }
        set {
            self.headers["Content-Disposition"] = newValue.flatMap { value in
                return HeaderValue(value.0, parameters: value.1)
            }.flatMap { value in
                return value.serialize()
            }
        }
    }
    
    public var contentType: String? {
        get { self.headers["Content-Type"] }
        set { self.headers["Content-Type"] = newValue }
    }

    /// Creates a new `MultipartPart`.
    ///
    ///     let part = MultipartPart(headers: ["Content-Type": "text/plain"], body: "hello")
    ///
    /// - parameters:
    ///     - headers: The part's headers.
    ///     - body: The part's data.
    public init(headers: [String: String] = [:], body: String) {
        self.init(headers: headers, body: [UInt8](body.utf8))
    }

    /// Creates a new `MultipartPart`.
    ///
    ///     let part = MultipartPart(headers: ["Content-Type": "text/plain"], body: "hello")
    ///
    /// - parameters:
    ///     - headers: The part's headers.
    ///     - body: The part's data.
    public init(headers: [String: String] = [:], body: [UInt8]) {
        self.headers = headers
        self.body = body
    }
    
    private func contentDispositionParameter(_ name: String) -> String? {
        guard let (_, parameters) = self.contentDisposition else {
            return nil
        }
        return parameters[name]
    }
    
    private mutating func setContentDispositionParameter(_ name: String, to value: String?) {
        var parameters: [String: String]
        let headerValue: String
        if let (existingValue, existingParameters) = self.contentDisposition {
            parameters = existingParameters
            headerValue = existingValue
        } else {
            parameters = [:]
            headerValue = "form-data"
        }
        parameters[name] = value
        self.contentDisposition = (headerValue, parameters)
    }
}

// MARK: Array Extensions

extension Array where Element == MultipartPart {
    /// Returns the first `MultipartPart` with matching name attribute in `"Content-Disposition"` header.
    public func firstPart(named name: String) -> MultipartPart? {
        for el in self {
            if el.name == name {
                return el
            }
        }
        return nil
    }

    /// Returns all `MultipartPart`s with matching name attribute in `"Content-Disposition"` header.
    public func allParts(named name: String) -> [MultipartPart] {
        return filter { $0.name == name }
    }
}
