enum MultipartFormData: Equatable {
    typealias Keyed = OrderedDictionary<String, MultipartFormData>

    case single(MultipartPart)
    case array([MultipartFormData])
    case keyed(Keyed)

    init(parts: [MultipartPart], nestingDepth: Int) {
        self = parts.reduce(into: .empty) { result, part in
            print(part.name.map(path))
            result.insertingPart(part, at: part.name.map(path) ?? [], remainingNestingLevels: nestingDepth)
        }
        print(self)
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
    mutating func insertingPart(_ part: MultipartPart, at path: ArraySlice<Substring>, remainingNestingLevels: Int) {
        self = insertPart(part, at: path, remainingNestingLevels: remainingNestingLevels)
    }

    func insertPart(_ part: MultipartPart,
                    at path: ArraySlice<Substring>,
                    remainingNestingLevels: Int) -> MultipartFormData {
        guard remainingNestingLevels > 0 else {
            return self
        }
        switch path.first {
        case .none:
            return .single(part)
        case "":
            switch path.dropFirst().first {
            case .none, "":
                return .array((array ?? []) + [MultipartFormData.empty.insertPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)])
            case let .some(head):
                if array == nil || array!.last!.dictionary!.keys.contains(String(head)) {
                    return .array((array ?? []) + [MultipartFormData.empty.insertPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)])
                } else {
                    return .array(array!.dropLast() + [array!.last!.insertPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)])
                }
            }
            
        case let .some(head):
            var dictionary = self.dictionary ?? [:]
            dictionary[String(head), default: .empty].insertingPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)
            return .keyed(dictionary)
        }
    }
}
