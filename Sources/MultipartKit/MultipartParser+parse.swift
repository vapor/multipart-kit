import HTTPTypes

extension MultipartParser {
    public func parse(_ data: Body) throws -> [MultipartPart<Body>] where Body: RangeReplaceableCollection {
        var output: [MultipartPart<Body>] = []
        var parser = MultipartParser(boundary: self.boundary)

        var currentHeaders: HTTPFields?
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
                        if let headers = currentHeaders {
                            // Merge multiple header fields into the current headers
                            currentHeaders = HTTPFields(headers + newFields)
                        } else {
                            currentHeaders = newFields
                        }
                    case .bodyChunk(let bodyChunk):
                        // Accumulate body chunks
                        currentBody.append(contentsOf: bodyChunk)
                    case .boundary:
                        // Create a MultipartPart when reaching a boundary
                        if let headers = currentHeaders {
                            output.append(MultipartPart(headerFields: headers, body: currentBody))
                        }
                        // Reset for the next part
                        currentHeaders = nil
                        currentBody = Body()
                    }
                }
            case .needMoreData:
                // No more data is available in synchronous parsing, this should never happen
                preconditionFailure("More data is needed")
            case .error(let error):
                throw error
            case .finished:
                // If finished, add any remaining part
                if let headers = currentHeaders {
                    output.append(MultipartPart(headerFields: headers, body: currentBody))
                }
                return output
            }
        }
    }
}
