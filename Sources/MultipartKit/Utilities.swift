import HTTPTypes

extension HTTPFields {
    /// Sets the `key` parameter of the `name` header field to `value`, or removes it when `value` is `nil`.
    /// A missing header field is created from `defaultValue`.
    mutating func setParameter(
        _ name: HTTPField.Name,
        _ key: String,
        to value: String?,
        defaultValue: String = "form-data"
    ) {
        let parameter = value.map { "\(key)=\"\($0)\"" }

        guard let existing = self[name] else {
            // The common case when encoding: build the value directly instead of splitting and joining.
            self[name] = parameter.map { "\(defaultValue); \($0)" } ?? defaultValue
            return
        }

        let key = key.lowercased()
        var newValue = ""
        newValue.reserveCapacity(existing.utf8.count + (parameter?.utf8.count ?? 0) + 2)
        for part in existing.headerValueParts() where part.prefix(while: { $0 != "=" }).trimmingWhitespace().lowercased() != key {
            if !newValue.isEmpty { newValue += "; " }
            newValue += part
        }
        if let parameter {
            if !newValue.isEmpty { newValue += "; " }
            newValue += parameter
        }
        self[name] = newValue
    }
}

extension StringProtocol where SubSequence == Substring {
    /// The `;`-separated parts of a header field value such as `form-data; name="a;b"`, each trimmed of
    /// surrounding whitespace. A `;` inside a quoted string doesn't separate parts, and empty parts are dropped.
    func headerValueParts() -> [Substring] {
        var parts: [Substring] = []
        parts.reserveCapacity(4)
        func appendPart(_ part: Substring) {
            let part = part.trimmingWhitespace()
            if !part.isEmpty {
                parts.append(part)
            }
        }

        var partStart = startIndex
        var isQuoted = false
        var index = startIndex

        while index < endIndex {
            switch self[index] {
            case "\\" where isQuoted:
                // A quoted pair: the next character is literal, even when it is a quote.
                index = self.index(after: index)
            case "\"":
                isQuoted.toggle()
            case ";" where !isQuoted:
                appendPart(self[partStart..<index])
                partStart = self.index(after: index)
            default:
                break
            }
            if index < endIndex {
                index = self.index(after: index)
            }
        }
        appendPart(self[partStart..<endIndex])

        return parts
    }
}

extension Substring {
    func trimmingWhitespace() -> Substring {
        let start = firstIndex { !$0.isWhitespace } ?? endIndex
        let end = lastIndex { !$0.isWhitespace }.map(index(after:)) ?? start
        return self[start..<end]
    }

    var unquoted: Substring {
        count >= 2 && first == "\"" && last == "\"" ? dropFirst().dropLast() : self
    }
}

extension UInt8 {
    @usableFromInline static let colon: UInt8 = 58
    @usableFromInline static let lf: UInt8 = 10
    @usableFromInline static let cr: UInt8 = 13
    @usableFromInline static let hyphen: UInt8 = 45
    @usableFromInline static let space: UInt8 = 32
}

extension Array where Element == UInt8 {
    @usableFromInline static let crlf: Self = [.cr, .lf]
    @usableFromInline static let twoHyphens: Self = [.hyphen, .hyphen]
    @usableFromInline static let colonSpace: Self = [.colon, .space]
}
