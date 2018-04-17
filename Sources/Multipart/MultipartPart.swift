/// A single part of a `multipart`-encoded message.
public struct MultipartPart {
    /// The part's raw data.
    public var data: Data

    /// The part's headers.
    public var headers: [CaseInsensitiveString: String]

    /// Gets or sets the `filename` attribute from the part's `"Content-Disposition"` header.
    public var filename: String? {
        get { return contentDisposition?.parameters["filename"] }
        set {
            var value: HeaderValue
            if let existing = contentDisposition {
                value = existing
            } else {
                value = HeaderValue("form-data")
            }
            value.parameters["filename"] = newValue
            contentDisposition = value
        }
    }

    /// Gets or sets the `name` attribute from the part's `"Content-Disposition"` header.
    public var name: String? {
        get { return contentDisposition?.parameters["name"] }
        set {
            var value: HeaderValue
            if let existing = contentDisposition {
                value = existing
            } else {
                value = HeaderValue("form-data")
            }
            value.parameters["name"] = newValue
            contentDisposition = value
        }
    }

    /// Gets or sets the part's `"Content-Disposition"` header.
    public var contentDisposition: HeaderValue? {
        get { return headers["Content-Disposition"].flatMap { HeaderValue.parse($0) } }
        set { headers["Content-Disposition"] = newValue?.serialize() }
    }

    /// Gets or sets the part's `"Content-Type"` header.
    public var contentType: MediaType? {
        get { return headers["Content-Type"].flatMap { MediaType.parse($0) } }
        set { headers["Content-Type"] = newValue?.serialize() }
    }

    /// Creates a new `MultipartPart`.
    ///
    ///     let part = MultipartPart(data "hello", headers: ["Content-Type": "text/plain"])
    ///
    /// - parameters:
    ///     - data: The part's data.
    ///     - headers: The part's headers.
    public init(data: LosslessDataConvertible, headers: [CaseInsensitiveString: String] = [:]) {
        self.data = data.convertToData()
        self.headers = headers
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

    /// Returns the first `MultipartPart` with matching filename attribute in `"Content-Disposition"` header.
    public func firstFile(filename: String) -> MultipartPart? {
        for el in self {
            if el.filename == filename {
                return el
            }
        }
        return nil
    }
}
