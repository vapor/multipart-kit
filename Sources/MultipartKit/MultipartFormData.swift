import struct OrderedCollections.OrderedDictionary

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

    var array: [MultipartFormData]? {
        guard case let .array(array) = self else { return nil }
        return array
    }

    var dictionary: Keyed? {
        guard case let .keyed(dict) = self else { return nil }
        return dict
    }

    var part: MultipartPart? {
        guard case let .single(part) = self else { return nil }
        return part
    }
}

private func path(from string: String) -> ArraySlice<Substring> {
    ArraySlice(string.replacingOccurrences(of: "]", with: "").split(omittingEmptySubsequences: false, whereSeparator: { $0 == "[" }))
}

extension MultipartFormData {
    func namedParts() -> [MultipartPart] {
        Self.namedParts(from: self)
    }

    private static func namedParts(from data: MultipartFormData, path: String? = nil) -> [MultipartPart] {
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
}

private extension MultipartFormData {
    mutating func insertingPart(_ part: MultipartPart, at path: ArraySlice<Substring>) {
        self = insertPart(part, at: path)
    }

    func insertPart(_ part: MultipartPart, at path: ArraySlice<Substring>) -> MultipartFormData {
        switch path.first {
        case .none:
            return .single(part)
        case "":
            return .array((array ?? []) + [MultipartFormData.empty.insertPart(part, at: path.dropFirst())])
        case let .some(head):
            var dictionary = self.dictionary ?? [:]
            dictionary[String(head), default: .empty].insertingPart(part, at: path.dropFirst())
            return .keyed(dictionary)
        }
    }
}
