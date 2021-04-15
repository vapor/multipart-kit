import struct OrderedCollections.OrderedDictionary

private func path(from string: String) -> ArraySlice<Substring> {
    ArraySlice(string.replacingOccurrences(of: "]", with: "").split(omittingEmptySubsequences: false, whereSeparator: { $0 == "[" }))
}

enum MultipartFormData: Equatable {
    typealias Keyed = OrderedDictionary<String, MultipartFormData>

    case single(MultipartPart)
    case array([MultipartFormData])
    case keyed(Keyed)

    init(parts: [MultipartPart]) {
        self = parts.reduce(into: .empty) { result, part in
            result.insertingPart(part, at: part.name.map(path) ?? [])
        }
    }

    static let empty = MultipartFormData.keyed([:])

    func namedParts() -> [MultipartPart] {
        Self.namedParts(from: self)
    }

    static func namedParts(from data: MultipartFormData, path: String? = nil) -> [MultipartPart] {
        switch data {
        case .array(let array):
            return array.flatMap { namedParts(from: $0, path: path.map { "\($0)[]" }) }
        case .single(var part):
            part.name = path
            return [part]
        case .keyed(let dictionary):
            return dictionary.flatMap { key, value in
                namedParts(from: value, path: path.map { "\($0)[\(key)]" } ?? key)
            }
        }
    }

    func insertPart(_ part: MultipartPart, at path: ArraySlice<Substring>) -> MultipartFormData {
        switch path.first {
        case .none:
            return .single(part)
        case "":
            return .array(array + [MultipartFormData.empty.insertPart(part, at: path.dropFirst())])
        case let .some(head):
            var dictionary = self.dictionary
            dictionary[String(head), default: .empty].insertingPart(part, at: path.dropFirst())
            return .keyed(dictionary)
        }
    }

    var array: [MultipartFormData] {
        if case let .array(array) = self {
            return array
        } else {
            return []
        }
    }

    var dictionary: Keyed {
        if case let .keyed(dict) = self {
            return dict
        } else {
            return [:]
        }
    }

    var part: MultipartPart? {
        if case let .single(part) = self {
            return part
        } else {
            return nil
        }
    }

    mutating func insertingPart(_ part: MultipartPart, at path: ArraySlice<Substring>) {
        self = insertPart(part, at: path)
    }
}
