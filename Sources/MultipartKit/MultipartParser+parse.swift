import HTTPTypes

extension MultipartParser {
    /// Synchronously parse the multipart data into an array of ``MultipartPart``.
    public func parse(_ data: Body) throws -> [MultipartPart<Body>] where Body: RangeReplaceableCollection {
        var output: [MultipartPart<Body>] = []
        var parser = MultipartParser(boundary: self.boundary)

        var currentHeaders = HTTPFields()
        var currentBody = Body()

        // Append all data at once since this is synchronous
        parser.append(buffer: data)

        while true {
            switch parser.read() {
            case .success(let optionalPart):
                guard let part = optionalPart else { continue }

                switch part {
                case .headerFields(let newFields):
                    currentHeaders.append(contentsOf: newFields)

                case .bodyChunk(let bodyChunk):
                    currentBody.append(contentsOf: bodyChunk)

                case .boundary:
                    if !currentHeaders.isEmpty {
                        output.append(MultipartPart(headerFields: currentHeaders, body: currentBody))
                        // Reset for next part
                        currentHeaders = HTTPFields()
                        currentBody = Body()
                    }
                }

            case .needMoreData:
                // In synchronous parsing with all data provided upfront,
                // needing more data indicates an incomplete/corrupted message
                throw MultipartMessageError.unexpectedEndOfFile

            case .error(let error):
                throw error

            case .finished:
                // Add final part if exists
                if !currentHeaders.isEmpty {
                    output.append(MultipartPart(headerFields: currentHeaders, body: currentBody))
                }
                return output
            }
        }
    }
}
