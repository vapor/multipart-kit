import HTTPTypes

extension MultipartParser {
    /// Synchronously parse the multipart data into an array of ``MultipartPart``.
    public func parse(_ data: Body) throws -> [MultipartPart<Body>] where Body: RangeReplaceableCollection {
        var output: [MultipartPart<Body>] = []
        var parser = MultipartParser(boundary: self.boundary)

        var currentHeaders: HTTPFields = .init()
        var currentBody = Body()

        // Append data to the parser and process the sections
        parser.append(buffer: data)

        while true {
            switch parser.read() {
            case .success(let optionalPart):
                switch optionalPart {
                case .none:
                    continue
                case .some(let part):
                    switch part {
                    case .headerFields(let newFields):
                        // Accumulate headers
                        currentHeaders.append(contentsOf: newFields)
                    case .bodyChunk(let bodyChunk):
                        // Accumulate body chunks
                        currentBody.append(contentsOf: bodyChunk)
                    case .boundary:
                        // Create a MultipartPart when reaching a boundary
                        if !currentHeaders.isEmpty {
                            output.append(MultipartPart(headerFields: currentHeaders, body: currentBody))
                        }
                        // Reset for the next part
                        currentHeaders = .init()
                        currentBody = .init()
                    }
                }
            case .needMoreData:
                // No more data is available in synchronous parsing, this should never happen
                preconditionFailure("More data is needed")
            case .error(let error):
                throw error
            case .finished:
                // If finished, add any remaining part
                if !currentHeaders.isEmpty {
                    output.append(MultipartPart(headerFields: currentHeaders, body: currentBody))
                }
                return output
            }
        }
    }
}
