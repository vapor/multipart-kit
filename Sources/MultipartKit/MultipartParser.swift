import HTTPTypes

struct MultipartParser {
    enum Error: Swift.Error {
        case invalidBoundary
        case invalidHeader(reason: String)
        case invalidBody(reason: String)
    }

    enum State {
        enum Part {
            case boundary
            case header(HTTPFields)
            case body(ArraySlice<UInt8>)
        }
        case idle
        case parsing(Part, ArraySlice<UInt8>)
        case finished
        case error(Error)
    }

    let boundary: ArraySlice<UInt8>
    private var state: State

    init(boundary: String) {
        self.boundary = ArraySlice(boundary.utf8)
        self.state = .idle
    }

    enum ReadResult {
        case success(reading: MultipartPart? = nil)
        case needMoreData
    }

    mutating func read() throws -> ReadResult {
        switch self.state {
        case .idle:
            self.state = .parsing(.boundary, .init())
            return .success()
        case .error(let error):
            throw error
        case .parsing(let part, let buffer):
            switch part {
            // TODO: handle initial boundary differently
            case .boundary:
                switch buffer.getIndexAfter(boundary) {
                case .wrongCharacter:  // abort
                    throw Error.invalidBoundary
                case .prematureEnd:  // ask for more data and retry
                    self.state = .parsing(.boundary, buffer)
                    return .needMoreData
                case let .success(index):  // move on to reading headers
                    self.state = .parsing(.header(.init()), buffer[..<index])
                    return .success()
                }
            case .header(var fields):
                // check for CRLF
                let indexAfterFirstCRLF: ArraySlice<UInt8>.Index
                switch buffer.getIndexAfter([13, 10]) {
                case .success(let index):
                    indexAfterFirstCRLF = index
                    self.state = .parsing(.header(fields), buffer[index...])
                case .wrongCharacter:
                    throw Error.invalidHeader(reason: "There should be a CRLF here")
                case .prematureEnd:
                    self.state = .parsing(.header(fields), buffer)
                    return .needMoreData
                }
                // TODO: check for another CRLF (end of headers)

                // read the header name until ':'
                guard
                    let endOfHeaderNameIndex = buffer[indexAfterFirstCRLF...].firstIndex(where: {
                        switch $0 {
                        case 0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B, 0x2D, 0x2E, 0x5E,
                            0x5F, 0x60, 0x7C, 0x7E, 0x30...0x39, 0x41...0x5A, 0x61...0x7A:
                            true
                        default: false
                        }
                    })
                else {
                    // we need more data, ":" has not appeared yet
                    self.state = .parsing(.header(fields), buffer)
                    return .needMoreData
                }

                let headerName = buffer[indexAfterFirstCRLF..<endOfHeaderNameIndex]

                // there should be a colon after the header name
                let indexAfterColonAndSpace: ArraySlice<UInt8>.Index
                switch buffer.getIndexAfter([58, 32]) {  // ": "
                case .wrongCharacter(at: let index):
                    throw Error.invalidHeader(reason: "Expected ': ' after header name, found \(buffer[index])")
                case .prematureEnd:
                    self.state = .parsing(.header(fields), buffer)
                    return .needMoreData
                case .success(let index):
                    indexAfterColonAndSpace = index
                }

                // read the header value until CRLF
                guard
                    let endOfHeaderValueIndex = buffer[indexAfterColonAndSpace...].firstIndex(where: { cr in
                        let next = buffer.firstIndex(of: cr)! + 1
                        switch (cr, buffer[next]) {
                        case (13, 10): return true
                        default: return false
                        }
                    })
                else {
                    // we need more data, CRLF has not appeared yet
                    self.state = .parsing(.header(fields), buffer)
                    return .needMoreData
                }

                let headerValue = buffer[indexAfterColonAndSpace..<endOfHeaderValueIndex]

                // add the header to the fields
                guard let name = HTTPField.Name(String(decoding: headerName, as: UTF8.self)) else {
                    throw Error.invalidHeader(reason: "Invalid header name")
                }
                let field = HTTPField(name: name, value: String(decoding: headerValue, as: UTF8.self))
                fields.append(field)

                // move on to reading the next header
                self.state = .parsing(.header(fields), buffer[endOfHeaderValueIndex...])
                return .success(reading: .headerField(field))
            case .body(let buffer):
                break
            }
        case .finished:
            return .success()
        }
    }
}

extension ArraySlice where Element == UInt8 {
    /// Returns the index after the given slice if it matches the start of the buffer.
    /// If the buffer is too short, it returns the index of the last character.
    /// If the buffer does not match the slice, it returns the index of the first mismatching character.
    /// - Parameters:
    ///     - slice: The slice to match against the buffer.
    /// - Returns: The index after the slice if it matches, or the index of the first mismatching character.
    func getIndexAfter(_ slice: ArraySlice<UInt8>) -> IndexAfterSlice {
        var resultIndex = self.startIndex
        for (index, element) in self.enumerated() {
            guard element == slice[index] else {
                return .wrongCharacter(at: index)
            }
            resultIndex = index
        }

        return .success(resultIndex)
    }
}

/// The result of a `getIndexAfter(_:)` call.
/// - success: The slice was found at the given index. The index is the index after the slice.
/// - wrongCharacter: The buffer did not match the slice. The index is the index of the first mismatching character.
/// - prematureEnd: The buffer was too short to contain the slice. The index is the index of the last character.
enum IndexAfterSlice {
    case success(ArraySlice<UInt8>.Index)
    case wrongCharacter(at: ArraySlice<UInt8>.Index)
    case prematureEnd(at: ArraySlice<UInt8>.Index)
}
