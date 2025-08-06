import Foundation
import HTTPTypes

extension HTTPFields {
    func getParameter(_ name: HTTPField.Name, _ key: String) -> String? {
        headerParts(name: name)?
            .filter { $0.starts(with: "\(key)=") }
            .first?
            .split(separator: "=")
            .last?
            .trimmingCharacters(in: .quotes)
    }

    mutating func setParameter(
        _ name: HTTPField.Name,
        _ key: String,
        to value: String?,
        defaultValue: String = "form-data"
    ) {
        var current: [String]

        if let existing = self.headerParts(name: name) {
            current = existing.filter { !$0.hasPrefix("\(key)=") }
        } else {
            current = [defaultValue]
        }

        if let value = value {
            current.append("\(key)=\"\(value)\"")
        }

        let new = current.joined(separator: "; ").trimmingCharacters(in: .whitespaces)

        self[name] = new
    }

    func headerParts(name: HTTPField.Name) -> [String]? {
        self[name]
            .flatMap {
                $0.split(separator: ";")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
    }
}

extension CharacterSet {
    static var quotes: CharacterSet {
        return .init(charactersIn: #""'"#)
    }
}

extension UInt8 {
    @usableFromInline static let colon: UInt8 = 58
    @usableFromInline static let lf: UInt8 = 10
    @usableFromInline static let cr: UInt8 = 13
    @usableFromInline static let hyphen: UInt8 = 45
    @usableFromInline static let space: UInt8 = 32
}

extension ArraySlice where Element == UInt8 {
    @usableFromInline static let crlf: Self = [.cr, .lf]
    @usableFromInline static let twoHyphens: Self = [.hyphen, .hyphen]
    @usableFromInline static let colonSpace: Self = [.colon, .space]
}
