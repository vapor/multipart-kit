// import struct Foundation.Data
// import struct Foundation.URL

// /// A protocol to provide custom behaviors for parsing and serializing types from and to multipart data.
// public protocol MultipartPartConvertible {
//     var multipart: MultipartPart? { get }

//     init?(multipart: MultipartPart)
// }

// // MARK: MultipartPart self-conformance

// extension MultipartPart: MultipartPartConvertible {
//     public var multipart: MultipartPart? {
//         self
//     }

//     public init?(multipart: MultipartPart) {
//         self = multipart
//     }
// }

// // MARK: String

// extension String: MultipartPartConvertible {
//     public var multipart: MultipartPart? {
//         .init(body: self)
//     }

//     public init?(multipart: MultipartPart) {
//         self.init(decoding: multipart.body.readableBytesView, as: UTF8.self)
//     }
// }

// // MARK: Numbers

// extension FixedWidthInteger {
//     public var multipart: MultipartPart? {
//         .init(body: self.description)
//     }

//     public init?(multipart: MultipartPart) {
//         self.init(String(multipart: multipart)!) // String.init(multipart:) never returns nil
//     }
// }

// extension Int: MultipartPartConvertible { }
// extension Int8: MultipartPartConvertible { }
// extension Int16: MultipartPartConvertible { }
// extension Int32: MultipartPartConvertible { }
// extension Int64: MultipartPartConvertible { }
// extension UInt: MultipartPartConvertible { }
// extension UInt8: MultipartPartConvertible { }
// extension UInt16: MultipartPartConvertible { }
// extension UInt32: MultipartPartConvertible { }
// extension UInt64: MultipartPartConvertible { }

// extension Float: MultipartPartConvertible {
//     public var multipart: MultipartPart? {
//         .init(body: self.description)
//     }

//     public init?(multipart: MultipartPart) {
//         self.init(String(multipart: multipart)!) // String.init(multipart:) never returns nil
//     }
// }

// extension Double: MultipartPartConvertible {
//     public var multipart: MultipartPart? {
//         .init(body: self.description)
//     }

//     public init?(multipart: MultipartPart) {
//         self.init(String(multipart: multipart)!) // String.init(multipart:) never returns nil
//     }
// }

// // MARK: Bool

// extension Bool: MultipartPartConvertible {
//     public var multipart: MultipartPart? {
//         .init(body: self.description)
//     }

//     public init?(multipart: MultipartPart) {
//         self.init(String(multipart: multipart)!) // String.init(multipart:) never returns nil
//     }
// }

// // MARK: Foundation types

// extension Data: MultipartPartConvertible {
//     public var multipart: MultipartPart? {
//         .init(body: self)
//     }

//     public init?(multipart: MultipartPart) {
//         self.init(multipart.body.readableBytesView)
//     }
// }

// extension URL: MultipartPartConvertible {
//     public var multipart: MultipartPart? {
//         .init(body: self.absoluteString)
//     }

//     public init?(multipart: MultipartPart) {
//         self.init(string: String(multipart: multipart)!) // String.init(multipart:) never returns nil
//     }
// }
