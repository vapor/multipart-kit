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
            case header
            case body
        }

        case initial
        case parsing(Part, ArraySlice<UInt8>)
        case finished
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
        case error(Error)
        case needMoreData
    }

    mutating func append(buffer: ArraySlice<UInt8>) {
        switch self.state {
        case .initial:
            self.state = .parsing(.boundary, buffer)
        case .parsing(let part, var existingBuffer):
            existingBuffer.append(contentsOf: buffer)
            self.state = .parsing(part, existingBuffer)
        case .finished:
            break
        }
    }

    mutating func read() -> ReadResult {
        switch self.state {
        case .initial:
            .needMoreData
        case .parsing(let part, let buffer):
            switch part {
            case .boundary:
                parseBoundary(from: buffer)
            case .header:
                parseHeader(from: buffer)
            case .body:
                parseBody(from: buffer)
            }
        case .finished:
            .finished
        }
    }

    private mutating func parseBoundary(from buffer: ArraySlice<UInt8>) -> ReadResult {
        switch buffer.getIndexAfter(boundary) {
        case .wrongCharacter:  // the boundary is unexpected
            return .error(Error.invalidBoundary)
        case .prematureEnd:  // ask for more data and retry
            self.state = .parsing(.boundary, buffer)
            return .needMoreData
        case let .success(index):
            switch buffer[index...].getIndexAfter([45, 45]) {  // check if it's the final boundary (ends with "--")
            case .success:  // if it is, finish
                self.state = .finished
                return .finished
            case .prematureEnd:
                return .needMoreData
            case .wrongCharacter:  // if it's not, move on to reading headers
                self.state = .parsing(.header, buffer[index...])
                return .success()
            }
        }
    }

    private mutating func parseBody(from buffer: ArraySlice<UInt8>) -> ReadResult {
        // read until CRLF
        switch buffer.getFirstRange(of: [13, 10]) {
        case .notFound, .prematureEnd:  // no CRLF or only CR. keep looking
            self.state = .parsing(.body, buffer)
            return .needMoreData

        case .success(let range):  // CRLF found
            let chunk = buffer[..<range.lowerBound]
            let bufferAfterCRLF = buffer[(range.upperBound)...]
            // check for end
            switch bufferAfterCRLF.getIndexAfter(boundary) {
            case .success:  // boundary found
                self.state = .parsing(.boundary, bufferAfterCRLF)
                return .success(reading: .bodyChunk(chunk))
            case .prematureEnd:
                return .needMoreData
            case .wrongCharacter:
                self.state = .parsing(.body, bufferAfterCRLF)
                return .success(reading: .bodyChunk(chunk))
            }
        }
    }

    private mutating func parseHeader(from buffer: ArraySlice<UInt8>) -> ReadResult {
        // check for CRLF
        let indexAfterFirstCRLF: ArraySlice<UInt8>.Index
        switch buffer.getIndexAfter([13, 10]) {
        case .success(let index):
            indexAfterFirstCRLF = index
            self.state = .parsing(.header, buffer[index...])
        case .wrongCharacter:
            return .error(Error.invalidHeader(reason: "There should be a CRLF here"))
        case .prematureEnd:
            self.state = .parsing(.header, buffer)
            return .needMoreData
        }

        // check for second CRLF (end of headers)
        switch buffer[indexAfterFirstCRLF...].getIndexAfter([13, 10]) {
        case .success(let index):  // end of headers found, move to body
            self.state = .parsing(.body, buffer[index...])
            return .success()
        case .wrongCharacter:  // no end of headers
            self.state = .parsing(.header, buffer[indexAfterFirstCRLF...])
        case .prematureEnd:  // might be end. ask for more data
            self.state = .parsing(.header, buffer)
            return .needMoreData
        }

        // read the header name until ":" or CR
        guard
            let endOfHeaderNameIndex = buffer[indexAfterFirstCRLF...].firstIndex(where: { element in
                element == 58 || element == 13  // ":" || CR
            })
        else {
            self.state = .parsing(.header, buffer)
            return .needMoreData
        }

        let headerName = buffer[indexAfterFirstCRLF..<endOfHeaderNameIndex]
        let headerWithoutName = buffer[endOfHeaderNameIndex...]

        // there should be a colon and space after the header name
        let indexAfterColonAndSpace: ArraySlice<UInt8>.Index
        switch headerWithoutName.getIndexAfter([58, 32]) {  // ": "
        case .wrongCharacter(at: let index):
            return .error(Error.invalidHeader(reason: "Expected ': ' after header name, found \(Character(UnicodeScalar(buffer[index])))"))
        case .prematureEnd:
            self.state = .parsing(.header, headerWithoutName)
            return .needMoreData
        case .success(let index):
            indexAfterColonAndSpace = index
        }

        // read the header value until CRLF
        let headerValue: ArraySlice<UInt8>
        switch buffer[indexAfterColonAndSpace...].getFirstRange(of: [13, 10]) {
        case .success(let range):
            headerValue = buffer[indexAfterColonAndSpace..<range.lowerBound]
        case .notFound, .prematureEnd:
            self.state = .parsing(.header, buffer)
            return .needMoreData
        }

        // add the header to the fields
        guard let name = HTTPField.Name(String(decoding: headerName, as: UTF8.self)) else {
            return .error(Error.invalidHeader(reason: "Invalid header name"))
        }
        let field = HTTPField(name: name, value: String(decoding: headerValue, as: UTF8.self))

        // move on to reading the next header
        self.state = .parsing(.header, buffer[headerValue.endIndex...])
        return .success(reading: .headerField(field))
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
        case success(Range<Index>)
        case notFound
        case prematureEnd
    }

    /// Returns the range of the matching slice if it matches.
    /// - Parameters:
    ///    - slice: The slice to match against the buffer.
    /// - Returns: The range of the matching slice if it matches, ``FirstIndexOfSliceResult/notFound`` if the slice was not
    ///     or ``FirstIndexOfSliceResult/prematureEnd``
    func getFirstRange(of slice: ArraySlice<UInt8>) -> FirstIndexOfSliceResult {
        guard !slice.isEmpty else { return .notFound }

        var sliceIndex = slice.startIndex
        var matchStartIndex: Index? = nil

        for (currentIndex, element) in self.enumerated() {
            if sliceIndex == slice.endIndex {
                // we've matched the entire slice
                let startIndex = self.index(self.startIndex, offsetBy: matchStartIndex!)
                let endIndex = self.index(self.startIndex, offsetBy: currentIndex)
                return .success(startIndex..<endIndex)
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
