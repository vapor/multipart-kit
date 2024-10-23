import HTTPTypes

struct MultipartParser {
    enum Error: Swift.Error, Equatable {
        case invalidBoundary
        case invalidHeader(reason: String)
        case invalidBody(reason: String)
    }

    enum State: Equatable {
        enum Part: Equatable {
            case boundary
            case header(HTTPFields)
            case body(ArraySlice<UInt8>)
        }

        case initial
        case parsing(Part, ArraySlice<UInt8>)
        case finished
        case error(Error)
    }

    let boundary: ArraySlice<UInt8>
    private var state: State

    init(boundary: String) {
        self.boundary = ArraySlice(boundary.utf8)
        self.state = .initial
    }

    enum ReadResult {
        case finished
        case success(reading: MultipartPart? = nil)
        case needMoreData
    }

    mutating func append(buffer: ArraySlice<UInt8>) {
        switch self.state {
        case .initial:
            self.state = .parsing(.boundary, buffer)
        case .error:
            break
        case .parsing(let part, var existingBuffer):
            existingBuffer.append(contentsOf: buffer)
            self.state = .parsing(part, existingBuffer)
        case .finished:
            break
        }
    }

    mutating func read() throws -> ReadResult {
        switch self.state {
        case .initial:
            return .needMoreData
        case .error(let error):
            throw error
        case .parsing(let part, let buffer):
            switch part {
            case .boundary:
                switch buffer.getIndexAfter(boundary) {
                case .wrongCharacter:  // abort
                    throw Error.invalidBoundary
                case .prematureEnd:  // ask for more data and retry
                    self.state = .parsing(.boundary, buffer)
                    return .needMoreData
                case let .success(index):
                    switch buffer[index...].getIndexAfter([45, 45]) {  // check if it's the final boundary
                    case .success:  // if it is, finish
                        self.state = .finished
                        return .finished
                    case .wrongCharacter, .prematureEnd:  // if it's not, move to reading headers
                        self.state = .parsing(.header(.init()), buffer[index...])
                        return .success()
                    }
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

                // check for second CRLF (end of headers)
                switch buffer[indexAfterFirstCRLF...].getIndexAfter([13, 10]) {
                case .success(let index):  // end of headers found, move to body
                    self.state = .parsing(.body([]), buffer[index...])
                    return .success()
                case .wrongCharacter:
                    self.state = .parsing(.header(fields), buffer[indexAfterFirstCRLF...])
                case .prematureEnd:
                    self.state = .parsing(.header(fields), buffer)
                    return .needMoreData
                }

                func getFirstUnsupportedCharacterIndex(in slice: ArraySlice<UInt8>) -> ArraySlice<UInt8>.Index? {
                    slice.firstIndex(where: {
                        switch $0 {
                        // allowed multipart header name characters
                        case 0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B, 0x2D, 0x2E, 0x5E,
                            0x5F, 0x60, 0x7C, 0x7E, 0x30...0x39, 0x41...0x5A, 0x61...0x7A:
                            false
                        default: true
                        }
                    })
                }

                // read the header name until ":"
                guard let endOfHeaderNameIndex = getFirstUnsupportedCharacterIndex(in: buffer[indexAfterFirstCRLF...]) else {
                    // we need more data, ": " has not appeared yet
                    self.state = .parsing(.header(fields), buffer)
                    return .needMoreData
                }

                let headerName = buffer[indexAfterFirstCRLF..<endOfHeaderNameIndex]
                let headerWithoutName = buffer[endOfHeaderNameIndex...]

                // there should be a colon and space after the header name
                let indexAfterColonAndSpace: ArraySlice<UInt8>.Index
                switch headerWithoutName.getIndexAfter([58, 32]) {  // ": "
                case .wrongCharacter(at: let index):
                    throw Error.invalidHeader(reason: "Expected ': ' after header name, found \(Character(UnicodeScalar(buffer[index])))")
                case .prematureEnd:
                    self.state = .parsing(.header(fields), headerWithoutName)
                    return .needMoreData
                case .success(let index):
                    indexAfterColonAndSpace = index
                }

                // read the header value until CRLF
                guard let endOfHeaderValueIndex = buffer[indexAfterColonAndSpace...].firstRange(of: [13, 10])?.lowerBound else {
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

            case .body(let chunk):
                switch buffer.firstIndexOf([13, 10]) {
                case .notFound, .prematureEnd:  // no CRLF or only CR. keep looking
                    self.state = .parsing(.body(chunk), buffer)
                    return .needMoreData

                case .success(let index):  // CRLF found
                    let chunk = buffer[..<index]
                    let bufferAfterCRLF = buffer[(index + 2)...]
                    // check for end
                    switch bufferAfterCRLF.getIndexAfter(boundary) {
                    case .success:  // boundary found
                        self.state = .parsing(.boundary, bufferAfterCRLF)
                        return .success(reading: .bodyChunk(chunk))
                    case .prematureEnd:
                        return .needMoreData
                    case .wrongCharacter:
                        self.state = .parsing(.body([]), bufferAfterCRLF)
                        return .success(reading: .bodyChunk(chunk))
                    }
                }

            }
        case .finished:
            return .finished
        }
    }
}

extension ArraySlice where Element == UInt8 {
    /// The result of a `getIndexAfter(_:)` call.
    /// - success: The slice was found at the given index. The index is the index after the slice.
    /// - wrongCharacter: The buffer did not match the slice. The index is the index of the first mismatching character.
    /// - prematureEnd: The buffer was too short to contain the slice. The index is the index of the last character.
    enum IndexAfterSlice {
        case success(ArraySlice<UInt8>.Index)
        case wrongCharacter(at: ArraySlice<UInt8>.Index)
        case prematureEnd(at: ArraySlice<UInt8>.Index)
    }

    /// Returns the index after the given slice if it matches the start of the buffer.
    /// If the buffer is too short, it returns the index of the last character.
    /// If the buffer does not match the slice, it returns the index of the first mismatching character.
    /// - Parameters:
    ///     - slice: The slice to match against the buffer.
    /// - Returns: The index after the slice if it matches, or the index of the first mismatching character.
    func getIndexAfter(_ slice: ArraySlice<UInt8>) -> IndexAfterSlice {
        var resultIndex = self.startIndex
        for element in slice {
            guard resultIndex < self.endIndex else {
                return .prematureEnd(at: resultIndex)
            }
            guard self[resultIndex] == element else {
                return .wrongCharacter(at: resultIndex)
            }
            resultIndex += 1
        }

        return .success(resultIndex)
    }

    /// The result of a `firstIndexOf(_:)` call.
    /// - Parameter success: The slice was found. The associated index is the index before the slice.
    /// - Parameter notFound: The slice was not found in the buffer.
    enum FirstIndexOfSliceResult {
        case success(ArraySlice<UInt8>.Index)
        case notFound
        case prematureEnd
    }

    /// Returns the start index of the given slice if it matches.
    /// - Parameters:
    ///    - slice: The slice to match against the buffer.
    /// - Returns: The start index the slice if it matches, or `.notFound` if the slice was not found.
    func firstIndexOf(_ slice: ArraySlice<UInt8>) -> FirstIndexOfSliceResult {
        guard !slice.isEmpty else { return .notFound }

        var sliceIndex = slice.startIndex
        var matchStartIndex: Index? = nil

        for (currentIndex, element) in self.enumerated() {
            if sliceIndex == slice.endIndex {
                // we've matched the entire slice
                return .success(self.index(self.startIndex, offsetBy: matchStartIndex!))
            }
            if element == slice[sliceIndex] {
                // matching char found
                if sliceIndex == slice.startIndex {
                    matchStartIndex = currentIndex
                }
                sliceIndex = slice.index(after: sliceIndex)
            } else {
                // reset
                sliceIndex = slice.startIndex
                matchStartIndex = nil

                // check if current char could start new match
                if element == slice[sliceIndex] {
                    matchStartIndex = currentIndex
                    sliceIndex = slice.index(after: sliceIndex)
                }
            }
        }
        if sliceIndex != slice.startIndex {
            return .prematureEnd
        }
        return .notFound
    }
}
