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
        let parameter = value.map { "\(key)=\"\($0.addingFormDataEscapes())\"" }

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
        for index in indices {
            switch self[index] {
            case "\"" where !isQuoted:
                isQuoted = true
            case "\"":
                // Not every sender escapes quotes inside a value, as in `name="a"b"`, so a quote only closes one
                // at the end, or before a `;` that leads to the next `key=` rather than to another quote.
                let rest = self[self.index(after: index)...].drop(while: \.isWhitespace)
                let nextQuoteOrKey = rest.dropFirst().first { $0 == "=" || $0 == ";" || $0 == "\"" }
                if rest.isEmpty || (rest.first == ";" && nextQuoteOrKey != "\"") {
                    isQuoted = false
                }
            case ";" where !isQuoted:
                appendPart(self[partStart..<index])
                partStart = self.index(after: index)
            default:
                break
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

    /// The text of a quoted string such as `"a\"b"` with its escapes undone, or the value as it is when it isn't
    /// quoted. Browsers write `"`, CR and LF as `%22`, `%0D` and `%0A`. Other senders write `"` as `\"` and leave
    /// `%` alone, so a value with a `\"` in it only has its `\"` and `\\` undone.
    var unquoted: String {
        guard count >= 2, first == "\"", last == "\"" else { return String(self) }
        let content = dropFirst().dropLast()

        var isBackslashEscaped = false
        var previous: Character?
        for character in content {
            if previous == "\\" && character == "\"" {
                isBackslashEscaped = true
                break
            }
            previous = character
        }

        return isBackslashEscaped ? content.removingBackslashEscapes() : content.removingPercentEscapes()
    }

    // Only a backslash before `"` or `\` is an escape, so the one in `C:\dir` stays.
    private func removingBackslashEscapes() -> String {
        var result = ""
        var index = startIndex
        while index < endIndex {
            let next = self.index(after: index)
            if self[index] == "\\", next < endIndex, self[next] == "\"" || self[next] == "\\" {
                index = next
            }
            result.append(self[index])
            index = self.index(after: index)
        }
        return result
    }

    private func removingPercentEscapes() -> String {
        guard contains("%") else { return String(self) }

        let pieces = split(separator: "%", omittingEmptySubsequences: false)
        var result = String(pieces[0])
        for piece in pieces.dropFirst() {
            switch piece.prefix(2).uppercased() {
            case "22": result += "\"" + piece.dropFirst(2)
            case "0D": result += "\r" + piece.dropFirst(2)
            case "0A": result += "\n" + piece.dropFirst(2)
            default: result += "%" + piece
            }
        }
        return result
    }
}

extension String {
    /// Escapes quotes and line breaks in a form-data name or filename the way browsers do,
    /// so the value can't end its quoted string early.
    func addingFormDataEscapes() -> String {
        guard unicodeScalars.contains(where: { $0 == "\"" || $0 == "\r" || $0 == "\n" }) else { return self }

        var escaped = ""
        for scalar in unicodeScalars {
            switch scalar {
            case "\"": escaped += "%22"
            case "\r": escaped += "%0D"
            case "\n": escaped += "%0A"
            default: escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped
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
