import Collections
import Foundation

enum MultipartFormData<Body: MultipartPartBodyElement>: Sendable {
    typealias Keyed = OrderedDictionary<String, MultipartFormData>

    case single(MultipartPart<Body>)
    case array([MultipartFormData])
    case keyed(Keyed)
    case nestingDepthExceeded

    init(parts: [MultipartPart<Body>], nestingDepth: Int) {
        self = .empty
        for part in parts {
            let path = part.name.map(makePath) ?? []
            insert(part, at: path, remainingNestingDepth: nestingDepth)
        }
    }

    static var empty: Self {
        MultipartFormData.keyed([:])
    }

    var array: [MultipartFormData]? {
        guard case .array(let array) = self else { return nil }
        return array
    }

    var dictionary: Keyed? {
        guard case .keyed(let dict) = self else { return nil }
        return dict
    }

    var part: MultipartPart<Body>? {
        guard case .single(let part) = self else { return nil }
        return part
    }

    var hasExceededNestingDepth: Bool {
        guard case .nestingDepthExceeded = self else {
            return false
        }
        return true
    }
}

private func makePath(from string: String) -> ArraySlice<String> {
    var result: ArraySlice<String> = [""]

    // This is a bit of a hack to handle brackets in the path. For example
    // `foo[a]a[b]` has to be decoded as `["foo", "a]a[b"]`,
    // so everything inside of the brackets has to be added in the name.
    // Unfortunately, while it may be possible according to the RFC,
    // there's no way of differentiating between the combination of `][` which
    // can both mean "close bracket and reopen",
    // and just be part of the value as normal characters, so `foo[a][b]` will
    // always be decoded as `["foo", "a", "b"]` and never as `["foo", "a][b"]`
    var i = string.startIndex
    var writeIndex = 0
    while i != string.endIndex {
        switch string[i] {
        case "[":
            writeIndex += 1
            result.append("")
            var j = string.index(i, offsetBy: 1)
            while !(string[j] == "]" && (j == string.index(before: string.endIndex) || string[string.index(j, offsetBy: 1)] == "[")) {
                result[writeIndex].append(string[j])
                j = string.index(after: j)
            }
            i = string.index(after: j)
        default:
            result[writeIndex].append(string[i])
            i = string.index(after: i)
        }
    }

    return result
}

extension MultipartFormData {
    func namedParts() -> [MultipartPart<Body>] {
        Self.namedParts(from: self)
    }

    private static func namedParts(from data: MultipartFormData, path: String? = nil) -> [MultipartPart<Body>] {
        switch data {
        case .array(let array):
            return array.enumerated().flatMap { offset, element in
                namedParts(from: element, path: path.map { "\($0)[\(offset)]" })
            }
        case .single(var part):
            part.name = path
            return [part]
        case .keyed(let dictionary):
            return dictionary.flatMap { key, value in
                namedParts(from: value, path: path.map { "\($0)[\(key)]" } ?? key)
            }
        case .nestingDepthExceeded:
            return []
        }
    }
}

extension MultipartFormData {
    fileprivate mutating func insert(_ part: MultipartPart<Body>, at path: ArraySlice<String>, remainingNestingDepth: Int) {
        self = inserting(part, at: path, remainingNestingDepth: remainingNestingDepth)
    }

    fileprivate func inserting(_ part: MultipartPart<Body>, at path: ArraySlice<String>, remainingNestingDepth: Int)
        -> MultipartFormData
    {
        guard let head = path.first else {
            return .single(part)
        }

        guard remainingNestingDepth > 1 else {
            return .nestingDepthExceeded
        }

        func insertPart(into data: inout MultipartFormData) {
            data.insert(part, at: path.dropFirst(), remainingNestingDepth: remainingNestingDepth - 1)
        }

        func insertingPart(at index: Int?) -> MultipartFormData {
            var array = self.array ?? []
            let count = array.count
            let index = index ?? count

            switch index {
            case count:
                array.append(.empty)
            case 0..<count:
                break
            default:
                // ignore indices outside the range of 0...count
                return self
            }

            insertPart(into: &array[index])
            return .array(array)
        }

        if head.isEmpty {
            return insertingPart(at: nil)
        } else if let index = Int(head) {
            return insertingPart(at: index)
        } else {
            var dictionary = self.dictionary ?? [:]
            insertPart(into: &dictionary[String(head), default: .empty])
            return .keyed(dictionary)
        }
    }
}
