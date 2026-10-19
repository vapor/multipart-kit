import HTTPTypes
import MultipartKit

struct File: Codable, Equatable, MultipartPartConvertible {
    let filename: String
    let data: [UInt8]

    enum MultipartError: Error {
        case invalidFileName
    }

    var headerFields: HTTPFields {
        [.contentDisposition: "form-data; name=\"image\"; filename=\"\(filename)\""]
    }

    func withBody<R>(_ closure: (RawSpan) throws -> R) rethrows -> R {
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            try closure(self.data.span.bytes)
        } else {
            try self.data.withUnsafeBytes { try closure($0.bytes) }
        }
    }

    init(filename: String, data: [UInt8]) {
        self.filename = filename
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case data, filename
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode([UInt8].self, forKey: .data)
        let filename = try container.decode(String.self, forKey: .filename)
        self.init(filename: filename, data: data)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(self.filename, forKey: .filename)
    }

    init(headerFields: HTTPFields, body: RawSpan) throws {
        let contentDisposition = headerFields[.contentDisposition] ?? ""

        let parameter = contentDisposition.split(separator: ";")
            .map { $0.drop(while: { $0 == " " || $0 == "\t" }) }
            .first { $0.hasPrefix("filename=") }
            .map { $0.dropFirst("filename=".count) }
        guard var parameter else { throw MultipartError.invalidFileName }
        if parameter.first == "\"" { parameter = parameter.dropFirst() }
        if parameter.last == "\"" { parameter = parameter.dropLast() }
        guard !parameter.isEmpty else { throw MultipartError.invalidFileName }

        let data = body.withUnsafeBytes { [UInt8]($0) }
        self.init(filename: String(parameter), data: data)
    }
}
