import HTTPTypes

public struct MultipartSerializer<Body: MultipartPartBodyElement>: Sendable
where Body: RangeReplaceableCollection {
    enum State {
        enum Part: Equatable {
            case boundary
            case header
            case body
        }

        case initial
        case serializing(Part, [MultipartSection<Body>])
        case finished
    }

    let boundary: String
    private(set) var state: State

    public init(boundary: String) {
        self.boundary = boundary
        self.state = .initial
    }

    mutating func append(_ element: MultipartSection<Body>) {
        switch self.state {
        case .initial:
            self.state = .serializing(.boundary, [element])
        case .serializing(let part, var existingBuffer):
            existingBuffer.append(element)
            self.state = .serializing(part, existingBuffer)
        case .finished:
            break
        }
    }

    enum WriteResult {
        case finished
        case serialized(Body? = nil)
        case needMoreData
        case error
    }

    mutating func write() -> WriteResult {
        switch self.state {
        case .initial:
            return .needMoreData
        case .serializing(let part, var buffer):
            switch part {
            case .boundary:
                let boundary = buffer.first
                buffer.removeFirst()
                self.state = .serializing(.header, buffer)
                if case .boundary(let isEndBoundary) = boundary {
                    return .serialized(serializeBoundary(isEndBoundary))
                }
                // should be unreachable
                return .error
            case .header:
                let headers = popFirst(from: &buffer, whereElementIs: MultipartSection<Body>.headerFields)
                switch buffer.first {
                case .headerFields: return .error  // shouldn't be possible
                case .bodyChunk: self.state = .serializing(.body, buffer)
                case .boundary: self.state = .serializing(.boundary, buffer)
                case nil: return .needMoreData
                }
                return .serialized(serializeHeaderFields(from: headers))
            case .body:
                let bodyChunks = popFirst(from: &buffer, whereElementIs: MultipartSection<Body>.bodyChunk)
                switch buffer.first {
                case .headerFields, .bodyChunk: return .error
                case .boundary: self.state = .serializing(.boundary, buffer)
                case nil: return .needMoreData
                }
                return .serialized(bodyChunks)
            }
        case .finished: return .finished
        }
    }

    private func serializeBoundary(_ isEndBoundary: Bool) -> Body {
        var buffer: Body = .init()
        buffer.append(.hyphen)
        buffer.append(.hyphen)
        buffer.append(contentsOf: boundary.utf8)
        buffer.append(contentsOf: ArraySlice<UInt8>.crlf)
        if isEndBoundary {
            buffer.append(.hyphen)
            buffer.append(.hyphen)
        }
        return buffer
    }

    private func serializeHeaderFields(from headers: HTTPFields) -> Body {
        var buffer: Body = .init()
        for field in headers {
            buffer.append(contentsOf: field.description.utf8)
            buffer.append(contentsOf: ArraySlice<UInt8>.crlf)
        }
        return buffer
    }

    private func popFirst(from array: inout [MultipartSection<Body>], matching: (MultipartSection<Body>) -> Bool)
        -> [MultipartSection<Body>]
    {
        var result: [MultipartSection<Body>] = []

        while !array.isEmpty, matching(array.first!) {
            result.append(array.removeFirst())
        }

        return result
    }

    func popFirst(from array: inout [MultipartSection<Body>], whereElementIs: @escaping (HTTPFields) -> MultipartSection<Body>)
        -> HTTPFields
    {
        let elements = popFirst(from: &array) { if case .headerFields = $0 { return true } else { return false } }
        var resultFields = HTTPFields()
        for element in elements {
            if case .headerFields(let fields) = element {
                resultFields.append(contentsOf: fields)
            }
        }
        return resultFields
    }

    func popFirst(from array: inout [MultipartSection<Body>], whereElementIs: @escaping (Body) -> MultipartSection<Body>)
        -> Body
    {
        let elements = popFirst(from: &array) { if case .bodyChunk = $0 { return true } else { return false } }
        var result = Body()
        for element in elements {
            if case .bodyChunk(let chunk) = element {
                result.append(contentsOf: chunk)
            }
        }
        return result
    }
}
