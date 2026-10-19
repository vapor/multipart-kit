import HTTPTypes

extension MultipartParser {
    struct StateMachine {
        enum State {
            case initial
            case parsing(Part)
            case finished
        }

        enum Part {
            case boundary
            case header
            case body
        }

        enum Section {
            case boundary(end: Bool)
            case headerFields(HTTPFields)
            case bodyChunk(Range<Int>)
        }

        enum Action {
            case emit(Section, consumed: Int)
            case feedMoreData(consumed: Int)
            case fail(MultipartParserError)
            case finished
        }

        var state: State
        let crlfWithBoundary: [UInt8]

        var boundary: [UInt8] { Array(crlfWithBoundary.dropFirst(2)) }

        mutating func read(_ bytes: Span<UInt8>) -> Action {
            guard !bytes.isEmpty else {
                if case .finished = self.state { return .finished }
                return .feedMoreData(consumed: 0)
            }

            return switch self.state {
            case .initial:
                parseBoundary(from: bytes)

            case .parsing(let part):
                switch part {
                case .boundary:
                    parseBoundary(from: bytes)

                case .header:
                    parseHeader(from: bytes)

                case .body:
                    parseBody(from: bytes)
                }

            case .finished: .finished
            }
        }

        private mutating func parseBoundary(from buffer: Span<UInt8>) -> Action {
            switch buffer.getIndexAfter(boundary) {
            case .wrongCharacter:  // the boundary is unexpected
                return .fail(.invalidBoundary)

            case .prematureEnd:  // ask for more data and retry
                self.state = .parsing(.boundary)
                return .feedMoreData(consumed: 0)

            case .success(let index):
                switch buffer.extracting(index...).getIndexAfter(.twoHyphens) {  // check if it's the final boundary (ends with "--")
                case .success:  // if it is, finish
                    self.state = .finished
                    return .emit(.boundary(end: true), consumed: buffer.count)

                case .prematureEnd:
                    return .feedMoreData(consumed: 0)

                case .wrongCharacter:  // if it's not, move on to reading headers
                    self.state = .parsing(.header)
                    return .emit(.boundary(end: false), consumed: index)
                }
            }
        }

        private mutating func parseBody(from buffer: Span<UInt8>) -> Action {
            // read until CRLF
            switch buffer.getFirstRange(of: crlfWithBoundary) {
            case .prematureEnd:  // found part of body end, request more data
                self.state = .parsing(.body)
                return .feedMoreData(consumed: 0)

            case .notFound:  // end not in sight, emit body chunk
                self.state = .parsing(.body)
                return .emit(.bodyChunk(buffer.indices), consumed: buffer.count)

            case .success(let range):  // end found
                self.state = .parsing(.boundary)
                return .emit(
                    .bodyChunk(0..<range.lowerBound),
                    consumed: range.lowerBound + 2  // advance two more bytes to avoid seeing end again
                )
            }
        }

        private mutating func parseHeader(from buffer: Span<UInt8>) -> Action {
            // check for CRLF
            let indexAfterFirstCRLF: Span.Index
            switch buffer.getIndexAfter(.crlf) {
            case .success(let index):
                indexAfterFirstCRLF = index
                self.state = .parsing(.header)

            case .wrongCharacter:
                return .fail(.invalidHeader(reason: "There should be a CRLF here"))

            case .prematureEnd:
                self.state = .parsing(.header)
                return .feedMoreData(consumed: 0)
            }

            // check for second CRLF (end of headers)
            switch buffer.extracting(indexAfterFirstCRLF...).getIndexAfter(.crlf) {
            case .success(let index):  // end of headers found, move to body
                self.state = .parsing(.body)
                return .emit(.headerFields([:]), consumed: indexAfterFirstCRLF + index)

            case .wrongCharacter:  // no end of headers
                self.state = .parsing(.header)

            case .prematureEnd:  // might be end. ask for more data
                self.state = .parsing(.header)
                return .feedMoreData(consumed: 0)
            }

            // read the header name until ":" or CR
            guard
                var endOfHeaderNameIndex = buffer.extracting(indexAfterFirstCRLF...).firstIndex(where: { element in
                    element == .colon || element == .cr
                })
            else {
                self.state = .parsing(.header)
                return .feedMoreData(consumed: 0)
            }

            endOfHeaderNameIndex += indexAfterFirstCRLF
            let headerName = buffer.extracting(indexAfterFirstCRLF..<endOfHeaderNameIndex)
            let headerWithoutName = buffer.extracting(endOfHeaderNameIndex...)

            // there should be a colon and space after the header name
            let indexAfterColonAndSpace: Span.Index
            switch headerWithoutName.getIndexAfter([UInt8.colon, .space]) {  // ": "
            case .wrongCharacter(at: let index):
                return .fail(
                    .invalidHeader(reason: "Expected ': ' after header name, found \(Character(UnicodeScalar(headerWithoutName[index])))")
                )

            case .prematureEnd:
                self.state = .parsing(.header)
                return .feedMoreData(consumed: 0)

            case .success(let index):
                indexAfterColonAndSpace = endOfHeaderNameIndex + index
            }

            // read the header value until CRLF
            let headerValue: Span<UInt8>
            let consumed: Int
            switch buffer.extracting(indexAfterColonAndSpace...).getFirstRange(of: .crlf) {
            case .success(let range):
                consumed = indexAfterColonAndSpace + range.lowerBound
                headerValue = buffer.extracting(indexAfterColonAndSpace..<(indexAfterColonAndSpace + range.lowerBound))

            case .notFound, .prematureEnd:
                self.state = .parsing(.header)
                return .feedMoreData(consumed: 0)
            }

            // add the header to the fields
            guard let name = HTTPField.Name(headerName.utf8String) else {
                return .fail(.invalidHeader(reason: "Invalid header name"))
            }

            let field = HTTPField(name: name, value: headerValue.utf8String)

            // move on to reading the next header
            return .emit(.headerFields(.init([field])), consumed: consumed)
        }
    }
}

extension Span where Element == UInt8 {
    /* @unsafe */ var utf8String: String {
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *),
            let utf8 = try? UTF8Span(validating: self)
        {
            String(copying: utf8)
        } else {
            self.withUnsafeBufferPointer { unsafe String(decoding: $0, as: UTF8.self) }
        }
    }
}

/// The result of a ``Swift/Span/getFirstRange(of:)`` call.
private enum FirstIndexOfSliceResult {
    /// The slice was found at the associated range.
    case success(Range<Int>)
    /// The slice was not found in the buffer.
    case notFound
    /// The buffer ends with the start of the slice, so more data is needed to tell.
    case prematureEnd
}

extension Span where Element == UInt8 {
    /// Returns the range of the first occurrence of `slice`, as offsets into this span.
    /// - Parameters:
    ///    - slice: The bytes to look for.
    /// - Returns: The range of the match, ``FirstIndexOfSliceResult/notFound`` if there is none,
    ///     or ``FirstIndexOfSliceResult/prematureEnd``.
    fileprivate func getFirstRange(of bytes: [UInt8]) -> FirstIndexOfSliceResult {
        guard !bytes.isEmpty else { return .notFound }
        let first = bytes[0]

        for start in 0..<self.count where self[start] == first {
            let available = Swift.min(bytes.count, self.count - start)
            var matched = 1
            while matched < available && self[start + matched] == bytes[matched] {
                matched += 1
            }
            if matched == bytes.count {
                return .success(start..<(start + bytes.count))
            }
            if matched == available {
                return .prematureEnd
            }
        }
        return .notFound
    }
}

extension Span where Element == UInt8 {
    /// The result of a ``Swift/Span/getIndexAfter(_:)`` call.
    enum IndexAfterSlice {
        /// The slice was found at the given index. The index is the index after the slice.
        case success(Span.Index)
        /// The buffer did not match the slice. The index is the index of the first mismatching character.
        case wrongCharacter(at: Span.Index)
        /// The buffer was too short to contain the slice. The index is the index of the last character.
        case prematureEnd(at: Span.Index)
    }

    /// Returns the index after the given slice if it matches the start of the buffer.
    /// If the buffer is too short, it returns the index of the last character.
    /// If the buffer does not match the slice, it returns the index of the first mismatching character.
    /// - Parameters:
    ///     - slice: The slice to match against the buffer.
    /// - Returns: The index after the slice if it matches, or the index of the first mismatching character.
    func getIndexAfter(_ bytes: [UInt8]) -> IndexAfterSlice {
        var resultIndex = 0

        for i in 0..<bytes.count {
            guard resultIndex < self.count else {
                return .prematureEnd(at: resultIndex)
            }
            guard self[resultIndex] == bytes[i] else {
                return .wrongCharacter(at: resultIndex)
            }
            resultIndex += 1
        }

        return .success(resultIndex)
    }
}

extension Span where Element == UInt8 {
    func firstIndex(where closure: (UInt8) -> Bool) -> Index? {
        for i in self.indices {
            if closure(self[i]) == true {
                return i
            }
        }
        return nil
    }
}
