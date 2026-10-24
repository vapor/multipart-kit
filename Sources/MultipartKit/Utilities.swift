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
        var index = startIndex

        while index < endIndex {
            switch self[index] {
            case "\\" where isQuoted:
                // A quoted pair: the next character is literal, even when it is a quote.
                index = self.index(after: index)
            case "\"" where isQuoted:
                // Some senders don't escape quotes inside a value, so only a quote before `;` or the end closes it.
                let rest = self[self.index(after: index)...].drop(while: \.isWhitespace)
                isQuoted = !(rest.isEmpty || rest.first == ";")
            case "\"" where self[..<index].last(where: { !$0.isWhitespace }) == "=":
                // A quoted string can only start a value; any other quote is part of the value.
                isQuoted = true
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

    /// The content of a quoted string such as `"a\"b"`, without its quotes and its `\"` and `\\` escapes,
    /// and whether it had any. A value that isn't quoted is returned as it is.
    func unquoted() -> (content: Substring, isEscaped: Bool) {
        guard count >= 2, first == "\"", last == "\"" else { return (self, false) }
        let content = dropFirst().dropLast()
        guard content.contains("\\") else { return (content, false) }

        var unescaped = ""
        var isEscaped = false
        var index = content.startIndex
        while index < content.endIndex {
            let next = content.index(after: index)
            // Browsers don't escape a backslash, so one only escapes a `"` or `\` after it, keeping `C:\dir` intact.
            if content[index] == "\\", next < content.endIndex, content[next] == "\"" || content[next] == "\\" {
                isEscaped = true
                unescaped.append(content[next])
                index = content.index(after: next)
            } else {
                unescaped.append(content[index])
                index = next
            }
        }
        return (isEscaped ? unescaped[...] : content, isEscaped)
    }

    /// Undoes the `%22`, `%0D` and `%0A` escapes browsers write in form-data names and filenames.
    /// Any other `%` is left as it is, as browsers don't escape it.
    func removingFormDataEscapes() -> String {
        guard contains("%") else { return String(self) }

        var result = ""
        var rest = self
        while let percent = rest.firstIndex(of: "%") {
            result += rest[..<percent]
            let escape = rest[percent...].prefix(3)
            switch escape {
            case "%22": result += "\""
            case "%0D", "%0d": result += "\r"
            case "%0A", "%0a": result += "\n"
            default:
                result += "%"
                rest = rest[rest.index(after: percent)...]
                continue
            }
            rest = rest[escape.endIndex...]
        }
        return result + rest
    }
}

extension String {
    /// Escapes quotes and line breaks in a form-data name or filename the way browsers do,
    /// so the value can't end its quoted string early.
    func addingFormDataEscapes() -> String {
        guard utf8.contains(where: { $0 == UInt8(ascii: "\"") || $0 == .cr || $0 == .lf }) else { return self }

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
