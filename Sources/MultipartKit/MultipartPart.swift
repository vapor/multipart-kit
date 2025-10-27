public import HTTPTypes

public typealias MultipartPartBodyElement = Collection<UInt8> & Sendable & RangeReplaceableCollection

/// Represents a single part of a multipart-encoded message.
public struct MultipartPart<Body: MultipartPartBodyElement>: Sendable {
    /// The header fields for this part.
    public var headerFields: HTTPFields

    /// The body of this part.
    public var body: Body

    /// Creates a new ``MultipartPart``.
    ///
    /// ```swift
    /// let part = MultipartPart(headerFields: [.contentDisposition: "form-data"], body: Array("Hello, world!".utf8))
    /// ```
    ///
    /// - Parameters:
    ///  - headerFields: The header fields for this part.
    ///  - body: The body of this part.
    public init(headerFields: HTTPFields = .init(), body: Body) {
        self.headerFields = headerFields
        self.body = body
    }

    /// Parses and returns the Content-Disposition information from the part's headers.
    ///
    /// - Throws: `ContentDisposition.Error` if the header has an invalid format, or is missing required fields.
    /// - Returns: A parsed `ContentDisposition` instance.
    public var contentDisposition: ContentDisposition? {
        get throws(ContentDisposition.Error) {
            guard let field = self.headerFields[.contentDisposition] else {
                return nil
            }
            return try .init(from: field)
        }
    }
}

/// Represents a parsed Content-Disposition header field for multipart messages.
///
/// The Content-Disposition header is defined in RFC 6266 (HTTP) and RFC 7578 (multipart/form-data)
/// and provides metadata about each part, including:
/// - The disposition type (form-data, attachment, inline)
/// - The "name" parameter that identifies the form field (required for form-data)
/// - An optional "filename" parameter for file uploads
/// - Any additional custom parameters
public struct ContentDisposition: Sendable {
    /// The original header field value.
    var underlyingField: String

    /// The type of content disposition, indicating how the content should be handled.
    ///
    /// The disposition type provides a hint to the recipient about how the content
    /// should be presented or processed.
    public let dispositionType: DispositionType

    /// The name parameter of the Content-Disposition header.
    ///
    /// This is a required parameter for multipart/form-data and represents
    /// the name of the form field associated with this part.
    public var name: String?

    /// The optional filename parameter of the Content-Disposition header.
    ///
    /// When present, this indicates the part contains an uploaded file and
    /// provides the original filename from the client.
    public let filename: String?

    /// Additional parameters included in the Content-Disposition header.
    ///
    /// These are any parameters beyond the standard "name" and "filename" parameters.
    public let additionalParameters: [String: String]

    /// Initializes a ContentDisposition by parsing a raw header field value.
    ///
    /// - Parameter field: The raw Content-Disposition header field value.
    /// - Throws: `ContentDisposition.Error` if the header has an invalid format, contains an
    ///           unrecognized disposition type, or is missing required fields.
    public init(from field: HTTPFields.Value) throws(ContentDisposition.Error) {
        self.underlyingField = field

        var parameters =
            field
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let dispositionType = parameters.removeFirst()
        guard let type = DispositionType(rawValue: dispositionType) else {
            throw Error.invalidDispositionType(String(dispositionType))
        }

        self.dispositionType = type

        var name: String?
        var filename: String?
        var additionalParameters: [String: String] = [:]

        for parameter in parameters {
            if parameter.starts(with: "name=") {
                if name != nil { throw Error.duplicateField("name") }
                name = parameter.dropFirst(5)
                    .trimmingCharacters(in: .quotes)
            } else if parameter.starts(with: "filename=") {
                if filename != nil { throw Error.duplicateField("filename") }
                filename = parameter.dropFirst(9)
                    .trimmingCharacters(in: .quotes)
            } else {
                var split = parameter.split(separator: "=")

                let name = String(split.removeFirst())
                let value = String(split.removeFirst().trimmingCharacters(in: .quotes))

                additionalParameters[name] = value
            }
        }

        // The name parameter is required when dealing with the form-data type
        if type == .formData, name == nil {
            throw Error.missingField("name")
        }

        self.name = name
        self.filename = filename
        self.additionalParameters = additionalParameters
    }

    /// The type of content disposition as defined in HTTP standards.
    /// Each disposition type indicates a different way the content should be handled.
    public enum DispositionType: String, Sendable {
        /// Indicates this part is a form field in a multipart/form-data submission.
        /// This is the standard disposition type used in HTML form submissions.
        case formData = "form-data"

        /// Indicates the content should be downloaded and saved locally rather than displayed.
        /// Attachment is commonly used for file downloads where the user is expected
        /// to save the content rather than view it in the browser or application.
        case attachment

        /// Indicates the content should be displayed inline within the context it was received.
        /// Inline content is typically rendered directly within a browser window
        /// or application view, rather than requiring a separate download step.
        case inline
    }

    /// Errors that can occur when parsing Content-Disposition headers.
    public struct Error: Swift.Error, Equatable {
        /// The underlying error type.
        enum Backing: Equatable {
            /// The disposition type is not "form-data" as required by RFC 7578.
            case invalidDispositionType(String)

            /// A field appears more than once in the header.
            case duplicateField(String)

            /// A required field is missing from the header.
            case missingField(String)

            /// The Content-Disposition header is not present.
            case missingContentDisposition
        }

        /// The backing error value.
        let backing: Backing

        /// Creates an error indicating an incorrect disposition type.
        ///
        /// - Parameter type: The invalid disposition type found in the header.
        /// - Returns: An error instance.
        public static func invalidDispositionType(_ type: String) -> Self {
            self.init(backing: .invalidDispositionType(type))
        }

        /// Creates an error indicating a duplicate field in the header.
        ///
        /// - Parameter field: The name of the duplicate field.
        /// - Returns: An error instance.
        public static func duplicateField(_ field: String) -> Self {
            self.init(backing: .duplicateField(field))
        }

        /// Creates an error indicating a missing required field.
        ///
        /// - Parameter field: The name of the missing field.
        /// - Returns: An error instance.
        public static func missingField(_ field: String) -> Self {
            self.init(backing: .missingField(field))
        }

        /// An error indicating the Content-Disposition header is missing.
        public static let missingContentDisposition = Self(backing: .missingContentDisposition)
    }
}
