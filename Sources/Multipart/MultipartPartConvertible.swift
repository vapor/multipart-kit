/// Supports converting to / from a `MultipartPart`.
public protocol MultipartPartConvertible {
    /// Converts `self` to `MultipartPart`.
    func convertToMultipartPart() throws -> MultipartPart

    /// Converts a `MultipartPart` to `Self`.
    static func convertFromMultipartPart(_ part: MultipartPart) throws -> Self
}

extension MultipartPart: MultipartPartConvertible {
    
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart { return self }
    
    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> MultipartPart { return part }
}

extension String: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: self)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> String {
        guard let string = String(data: part.data, encoding: .utf8) else {
            throw MultipartError(identifier: "utf8", reason: "Could not convert `Data` to UTF-8 `String`.")
        }
        return string
    }
}

extension FixedWidthInteger {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: description, headers: [:])
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Self {
        guard let fwi = String(data: part.data, encoding: .utf8).flatMap({ Self($0 )}) else {
            throw MultipartError(identifier: "int", reason: "Could not convert `Data` to `\(Self.self)`.")
        }
        return fwi
    }
}

extension Int: MultipartPartConvertible { }
extension Int8: MultipartPartConvertible { }
extension Int16: MultipartPartConvertible { }
extension Int32: MultipartPartConvertible { }
extension Int64: MultipartPartConvertible { }
extension UInt: MultipartPartConvertible { }
extension UInt8: MultipartPartConvertible { }
extension UInt16: MultipartPartConvertible { }
extension UInt32: MultipartPartConvertible { }
extension UInt64: MultipartPartConvertible { }


extension Float: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Float {
        guard let float = String(data: part.data, encoding: .utf8).flatMap({ Float($0 )}) else {
            throw MultipartError(identifier: "float", reason: "Could not convert `Data` to `\(Float.self)`.")
        }
        return float
    }
}

extension Double: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Double {
        guard let double = String(data: part.data, encoding: .utf8).flatMap({ Double($0 )}) else {
            throw MultipartError(identifier: "double", reason: "Could not convert `Data` to `\(Double.self)`.")
        }
        return double
    }
}

extension Bool: MultipartPartConvertible {
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: description)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Bool {
        guard let stringValue = String(data: part.data, encoding: .utf8) else {
            throw MultipartError(identifier: "utf8", reason: "Could not convert `Data` to UTF-8 `Bool`.")
        }
        let options = ["true": true, "false": false]
        guard let option = options[stringValue] else {
            throw MultipartError(identifier: "boolean", reason: "Could not convert `Data` to boolean `Bool`. Must be one of \(options)")
        }
        return option
    }
}

extension File: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        var part = MultipartPart(data: data)
        part.filename = filename
        part.contentType = contentType
        return part
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> File {
        guard let filename = part.filename else {
            throw MultipartError(identifier: "filename", reason: "Multipart part missing a filename.")
        }
        return File(data: part.data, filename: filename)
    }
}

extension Data: MultipartPartConvertible {
    /// See `MultipartPartConvertible`.
    public func convertToMultipartPart() throws -> MultipartPart {
        return MultipartPart(data: self)
    }

    /// See `MultipartPartConvertible`.
    public static func convertFromMultipartPart(_ part: MultipartPart) throws -> Data {
        return part.data
    }
}
