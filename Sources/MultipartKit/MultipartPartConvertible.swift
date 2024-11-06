import struct Foundation.Data
import struct Foundation.URL

/// A protocol to provide custom behaviors for parsing and serializing types from and to multipart data.
public protocol MultipartPartConvertible<Body> {
    associatedtype Body: MultipartPartBodyElement

    var multipart: MultipartPart<Body>? { get }
    init?(multipart: MultipartPart<Body>)
}

// MARK: MultipartPart self-conformance

extension MultipartPart: MultipartPartConvertible {
    public var multipart: MultipartPart<Body>? {
        self
    }

    public init?(multipart: MultipartPart<Body>) {
        self = multipart
    }
}

// MARK: String

extension String: MultipartPartConvertible {
    public typealias Body = [UInt8]

    public var multipart: MultipartPart<[UInt8]>? {
        MultipartPart(headerFields: [:], body: Array(self.utf8))
    }

    public init?(multipart: MultipartPart<[UInt8]>) {
        guard let string = String(bytes: multipart.body, encoding: .utf8) else {
            return nil
        }
        self = string
    }
}

// MARK: Numbers

extension FixedWidthInteger {
    public typealias Body = [UInt8]

    public var multipart: MultipartPart<[UInt8]>? {
        self.description.multipart
    }

    public init?(multipart: MultipartPart<[UInt8]>) {
        guard let str = String(bytes: multipart.body, encoding: .utf8),
            let value = Self(str)
        else {
            return nil
        }
        self = value
    }
}

extension Int: MultipartPartConvertible {}
extension Int8: MultipartPartConvertible {}
extension Int16: MultipartPartConvertible {}
extension Int32: MultipartPartConvertible {}
extension Int64: MultipartPartConvertible {}
extension UInt: MultipartPartConvertible {}
extension UInt8: MultipartPartConvertible {}
extension UInt16: MultipartPartConvertible {}
extension UInt32: MultipartPartConvertible {}
extension UInt64: MultipartPartConvertible {}

// MARK: Floating Point Numbers

extension Float: MultipartPartConvertible {
    public typealias Body = [UInt8]

    public var multipart: MultipartPart<[UInt8]>? {
        self.description.multipart
    }

    public init?(multipart: MultipartPart<[UInt8]>) {
        guard let str = String(bytes: multipart.body, encoding: .utf8),
            let value = Float(str)
        else {
            return nil
        }
        self = value
    }
}

extension Double: MultipartPartConvertible {
    public typealias Body = [UInt8]

    public var multipart: MultipartPart<[UInt8]>? {
        self.description.multipart
    }

    public init?(multipart: MultipartPart<[UInt8]>) {
        guard let str = String(bytes: multipart.body, encoding: .utf8),
            let value = Double(str)
        else {
            return nil
        }
        self = value
    }
}

// MARK: Bool

extension Bool: MultipartPartConvertible {
    public typealias Body = [UInt8]

    public var multipart: MultipartPart<[UInt8]>? {
        self.description.multipart
    }

    public init?(multipart: MultipartPart<[UInt8]>) {
        guard let str = String(bytes: multipart.body, encoding: .utf8),
            let value = Bool(str)
        else {
            return nil
        }
        self = value
    }
}

// MARK: Foundation types

extension Data: MultipartPartConvertible {
    public typealias Body = [UInt8]

    public var multipart: MultipartPart<[UInt8]>? {
        MultipartPart(headerFields: [:], body: Array(self))
    }

    public init?(multipart: MultipartPart<[UInt8]>) {
        self.init(multipart.body)
    }
}

extension URL: MultipartPartConvertible {
    public typealias Body = [UInt8]

    public var multipart: MultipartPart<[UInt8]>? {
        self.absoluteString.multipart
    }

    public init?(multipart: MultipartPart<[UInt8]>) {
        guard let str = String(bytes: multipart.body, encoding: .utf8),
            let url = URL(string: str)
        else {
            return nil
        }
        self = url
    }
}
