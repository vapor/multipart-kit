enum MultipartFormData: Equatable {
    typealias Keyed = OrderedDictionary<String, MultipartFormData>

    case single(MultipartPart)
    case array([MultipartFormData])
    case keyed(Keyed)

    init(parts: [MultipartPart], nestingDepth: Int) {
        self = parts.reduce(into: .empty) { result, part in
            result.insertingPart(part, at: part.name.map(path) ?? [], remainingNestingLevels: nestingDepth)
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
            return array.enumerated().flatMap { i, part in
                namedParts(from: part,
                           path: {
                            if case .keyed = part {
                                return path.map { "\($0)[\(i)]" }
                            }
                            return path.map { "\($0)[]" }
                           }())
            }
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
                if array == nil || (array!.last!.dictionary!.keys.contains(String(head)) && path.count == 2) {
                    return .array((array ?? []) + [MultipartFormData.empty.insertPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)])
                } else {
                    return .array(array!.dropLast() + [array!.last!.insertPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)])
                }
            }
            
        case let .some(head):
            /// added for nested array indices
            if let index = Int(head) {
                if array == nil {
                    return .array([MultipartFormData.empty.insertPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)])
                }
                return .array(index > array!.count - 1 ?
                                array! + [MultipartFormData.empty.insertPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)]
                                : array!.dropLast() + [array!.last!.insertPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)])
            }
            /// for obj keys.
            var dictionary = self.dictionary ?? [:]
            dictionary[String(head), default: .empty].insertingPart(part, at: path.dropFirst(), remainingNestingLevels: remainingNestingLevels - 1)
            return .keyed(dictionary)
        }
    }
}
