import MultipartKit

struct File: Codable, Equatable, MultipartPartConvertible {
    let filename: String
    let data: [UInt8]

    enum MultipartError: Error {
        case invalidFileName
    }

    enum CodingKeys: String, CodingKey {
        case data, filename
    }

    init(filename: String, data: [UInt8]) {
        self.filename = filename
        self.data = data
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

    var multipart: MultipartPart<[UInt8]> {
        let part = MultipartPart(
            headerFields: [.contentDisposition: "form-data; name=\"image\"; filename=\"\(filename)\""],
            body: self.data
        )
        return part
    }

    init(multipart: MultipartPart<some MultipartPartBodyElement>) throws {
        let contentDisposition = multipart.headerFields[.contentDisposition] ?? ""
        let filenamePattern = "filename=\"([^\"]+)\""
        let filename: String

        if let range = contentDisposition.range(of: filenamePattern, options: .regularExpression) {
            let match = contentDisposition[range]
            let startIndex = match.index(match.startIndex, offsetBy: 10)  // Skip 'filename="'
            let endIndex = match.index(before: match.endIndex)  // Skip closing quote
            filename = String(contentDisposition[startIndex..<endIndex])
        } else {
            throw MultipartError.invalidFileName
        }

        self.init(filename: filename, data: Array(multipart.body))
    }
}
