import HTTPTypes

/// Parses any kind of multipart encoded data into ``MultipartSection``s.
public struct MultipartParser<Body: MultipartPartBodyElement> where Body: RangeReplaceableCollection {
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
    private(set) var state: State

    init(boundary: some Collection<UInt8>) {
        self.boundary = .init(boundary)
        self.state = .initial
    }

    public init(boundary: String) {
        self.boundary = .twoHyphens + ArraySlice(boundary.utf8)
        self.state = .initial
    }

    enum ReadResult {
        case finished
        case success(reading: MultipartSection<Body>? = nil)
        case error(MultipartParserError)
        case needMoreData
    }

    mutating func append(buffer: Body) {
        switch self.state {
        case .initial:
            self.state = .parsing(.boundary, .init(buffer))
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
            return .error(.invalidBoundary)
        case .prematureEnd:  // ask for more data and retry
            self.state = .parsing(.boundary, buffer)
            return .needMoreData
        case let .success(index):
            switch buffer[index...].getIndexAfter(.twoHyphens) {  // check if it's the final boundary (ends with "--")
            case .success:  // if it is, finish
                self.state = .finished
                return .success(reading: .boundary(end: true))
            case .prematureEnd:
                return .needMoreData
            case .wrongCharacter:  // if it's not, move on to reading headers
                self.state = .parsing(.header, buffer[index...])
                return .success(reading: .boundary(end: false))
            }
        }
    }

    private mutating func parseBody(from buffer: ArraySlice<UInt8>) -> ReadResult {
        // read until CRLF
        switch buffer.getFirstRange(of: .crlf + boundary) {
        case .prematureEnd:  // found part of body end, request more data
            self.state = .parsing(.body, buffer)
            return .needMoreData
        case .notFound:  // end not in sight, emit body chunk
            if buffer.isEmpty {
                self.state = .parsing(.body, buffer)
                return .needMoreData
            }
            self.state = .parsing(.body, [])
            return .success(reading: .bodyChunk(.init(buffer)))
        case .success(let range):  // end found
            let chunk = buffer[..<range.lowerBound]
            let bufferAfterCRLF = buffer[(range.lowerBound + 2)...]
            self.state = .parsing(.boundary, bufferAfterCRLF)
            return .success(reading: .bodyChunk(.init(chunk)))
        }
    }

    private mutating func parseHeader(from buffer: ArraySlice<UInt8>) -> ReadResult {
        // check for CRLF
        let indexAfterFirstCRLF: ArraySlice<UInt8>.Index
        switch buffer.getIndexAfter(.crlf) {
        case .success(let index):
            indexAfterFirstCRLF = index
            self.state = .parsing(.header, buffer[index...])
        case .wrongCharacter:
            return .error(.invalidHeader(reason: "There should be a CRLF here"))
        case .prematureEnd:
            self.state = .parsing(.header, buffer)
            return .needMoreData
        }

        // check for second CRLF (end of headers)
        switch buffer[indexAfterFirstCRLF...].getIndexAfter(.crlf) {
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
                element == .colon || element == .cr
            })
        else {
            self.state = .parsing(.header, buffer)
            return .needMoreData
        }

        let headerName = buffer[indexAfterFirstCRLF..<endOfHeaderNameIndex]
        let headerWithoutName = buffer[endOfHeaderNameIndex...]

        // there should be a colon and space after the header name
        let indexAfterColonAndSpace: ArraySlice<UInt8>.Index
        switch headerWithoutName.getIndexAfter([.colon, .space]) {  // ": "
        case .wrongCharacter(at: let index):
            return .error(.invalidHeader(reason: "Expected ': ' after header name, found \(Character(UnicodeScalar(buffer[index])))"))
        case .prematureEnd:
            self.state = .parsing(.header, buffer)
            return .needMoreData
        case .success(let index):
            indexAfterColonAndSpace = index
        }

        // read the header value until CRLF
        let headerValue: ArraySlice<UInt8>
        switch buffer[indexAfterColonAndSpace...].getFirstRange(of: .crlf) {
        case .success(let range):
            headerValue = buffer[indexAfterColonAndSpace..<range.lowerBound]
        case .notFound, .prematureEnd:
            self.state = .parsing(.header, buffer)
            return .needMoreData
        }

        // add the header to the fields
        guard let name = HTTPField.Name(String(decoding: headerName, as: UTF8.self)) else {
            return .error(.invalidHeader(reason: "Invalid header name"))
        }
        let field = HTTPField(name: name, value: String(decoding: headerValue, as: UTF8.self))

        // move on to reading the next header
        self.state = .parsing(.header, buffer[headerValue.endIndex...])
        return .success(reading: .headerFields(.init([field])))
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
