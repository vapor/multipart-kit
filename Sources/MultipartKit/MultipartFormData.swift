import Collections
import Foundation

/// Internal representation of parsed multipart form data with support for hierarchical structures.
///
/// This type is used by the `FormDataDecoder` to represent the hierarchical structure
/// of multipart form data, with support for nested objects and arrays through
/// field name notation like `user[address][street]`.
enum MultipartFormData<Body: MultipartPartBodyElement>: Sendable {
    typealias Keyed = OrderedDictionary<String, MultipartFormData>

    /// A single multipart part containing field data.
    case single(MultipartPart<Body>)

    /// An array of form data items (represents indexed fields like `items[]`).
    case array([MultipartFormData])

    /// A keyed dictionary of form data items (represents nested objects like `user[name]`).
    case keyed(Keyed)

    /// Special case when the nesting depth limit has been exceeded.
    case nestingDepthExceeded

    init(parts: [MultipartPart<Body>], nestingDepth: Int) {
        self = .empty
        for part in parts {
            let name = try? part.contentDisposition?.name
            let path = name.map(makePath) ?? []
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

    /// Whether this form data has exceeded the configured nesting depth.
    ///
    /// Used during decoding to detect and handle excessive nesting that could
    /// lead to stack overflow or other resource issues.
    var hasExceededNestingDepth: Bool {
        guard case .nestingDepthExceeded = self else {
            return false
        }
        return true
    }
}

/// Parses a string with bracket notation into a path of components.
///
/// For example:
/// - `"user[address][street]"` becomes `["user", "address", "street"]`
/// - `"items[0][name]"` becomes `["items", "0", "name"]`
///
/// This function handles complex cases like brackets within values and
/// properly manages the path segments.
private func makePath(from string: String) -> ArraySlice<String> {
    // This is a bit of a hack to handle brackets in the path. For example
    // `foo[a]a[b]` has to be decoded as `["foo", "a]a[b"]`,
    // so everything inside of the brackets has to be added in the name.
    // Unfortunately, while it may be possible according to the RFC,
    // there's no way of differentiating between the combination of `][` which
    // can both mean "close bracket and reopen",
    // and just be part of the value as normal characters, so `foo[a][b]` will
    // always be decoded as `["foo", "a", "b"]` and never as `["foo", "a][b"]`

    if string.isEmpty { return [""] }

    var result: ArraySlice = [""]
    var writeIndex = 0
    var currentIndex = string.startIndex

    while currentIndex < string.endIndex {
        if string[currentIndex] == "[" {
            writeIndex += 1
            result.append("")
            currentIndex = string.index(after: currentIndex)

            while currentIndex < string.endIndex
                && !(string[currentIndex] == "]"
                    && (currentIndex == string.index(before: string.endIndex) || string[string.index(after: currentIndex)] == "["))
            {
                result[writeIndex].append(string[currentIndex])
                currentIndex = string.index(after: currentIndex)
            }

            if currentIndex < string.endIndex { currentIndex = string.index(after: currentIndex) }
        } else {
            result[writeIndex].append(string[currentIndex])
            currentIndex = string.index(after: currentIndex)
        }
    }

    return result
}

extension MultipartFormData {
    /// Converts the hierarchical form data structure back to flat multipart parts.
    ///
    /// This method is used by `FormDataEncoder` to convert the structured form data
    /// back to a flat list of parts with appropriate `name` attributes in their
    /// Content-Disposition headers.
    func namedParts() -> [MultipartPart<Body>] {
        Self.namedParts(from: self)
    }

    private static func namedParts(from data: MultipartFormData, path: String? = nil) -> [MultipartPart<Body>] {
        switch data {
        case .single(let part):
            // Create a new part with the updated name parameter
            [createPartWithName(part, name: path)]
        case .array(let array):
            // For arrays, index each element and process recursively
            array.enumerated().flatMap { offset, element in
                namedParts(from: element, path: path.map { "\($0)[\(offset)]" })
            }
        case .keyed(let dictionary):
            // For objects, process each key-value pair recursively
            dictionary.flatMap { key, value in
                namedParts(from: value, path: path.map { "\($0)[\(key)]" } ?? key)
            }
        case .nestingDepthExceeded:
            []
        }
    }

    /// Creates a new part with the given name parameter in its Content-Disposition header.
    private static func createPartWithName(_ part: MultipartPart<Body>, name: String?) -> MultipartPart<Body> {
        var headerFields = part.headerFields
        headerFields.setParameter(.contentDisposition, "name", to: name)

        return MultipartPart(
            headerFields: headerFields,
            body: part.body
        )
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
