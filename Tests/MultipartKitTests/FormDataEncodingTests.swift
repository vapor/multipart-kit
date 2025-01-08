import MultipartKit
import Testing

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

@Suite("Form Data Encoding Tests")
struct FormDataEncodingTests {
    @Test("Encoding")
    func encode() throws {
        struct Foo: Encodable {
            var string: String
            var int: Int
            var double: Double
            var array: [Int]
            var bool: Bool
        }
        let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3], bool: true)
        let data = try FormDataEncoder().encode(a, boundary: "hello", to: [UInt8].self)
        #expect(
            data
                == Array(
                    """
                    --hello\r
                    Content-Disposition: form-data; name="string"\r
                    \r
                    a\r
                    --hello\r
                    Content-Disposition: form-data; name="int"\r
                    \r
                    42\r
                    --hello\r
                    Content-Disposition: form-data; name="double"\r
                    \r
                    3.14\r
                    --hello\r
                    Content-Disposition: form-data; name="array[0]"\r
                    \r
                    1\r
                    --hello\r
                    Content-Disposition: form-data; name="array[1]"\r
                    \r
                    2\r
                    --hello\r
                    Content-Disposition: form-data; name="array[2]"\r
                    \r
                    3\r
                    --hello\r
                    Content-Disposition: form-data; name="bool"\r
                    \r
                    true\r
                    --hello--\r\n
                    """.utf8
                )
        )
    }

    @Test("Nested Encoding")
    func nestedEncode() throws {
        struct FormData: Encodable, Equatable {
            struct NestedFormdata: Encodable, Equatable {
                struct AnotherNestedFormdata: Encodable, Equatable {
                    let int: Int
                    let string: String
                    let strings: [String]
                }
                let int: String
                let string: Int
                let strings: [String]
                let anotherNestedFormdata: AnotherNestedFormdata
                let anotherNestedFormdataList: [AnotherNestedFormdata]
            }
            let nestedFormdata: [NestedFormdata]
        }

        let encoder = FormDataEncoder()
        let data = try encoder.encode(
            FormData(nestedFormdata: [
                .init(
                    int: "1",
                    string: 1,
                    strings: ["2", "3"],
                    anotherNestedFormdata: .init(int: 4, string: "5", strings: ["6", "7"]),
                    anotherNestedFormdataList: [
                        .init(int: 10, string: "11", strings: ["12", "13"]),
                        .init(int: 20, string: "21", strings: ["22", "33"]),
                    ])
            ]), boundary: "-")
        let expected =
            """
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][int]"\r
            \r
            1\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][string]"\r
            \r
            1\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][strings][0]"\r
            \r
            2\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][strings][1]"\r
            \r
            3\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdata][int]"\r
            \r
            4\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdata][string]"\r
            \r
            5\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdata][strings][0]"\r
            \r
            6\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdata][strings][1]"\r
            \r
            7\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][0][int]"\r
            \r
            10\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][0][string]"\r
            \r
            11\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][0][strings][0]"\r
            \r
            12\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][0][strings][1]"\r
            \r
            13\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][1][int]"\r
            \r
            20\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][1][string]"\r
            \r
            21\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][1][strings][0]"\r
            \r
            22\r
            ---\r
            Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][1][strings][1]"\r
            \r
            33\r
            -----\r\n
            """

        #expect(data == expected)
    }

    @Test("Encoding and Decoding UUID")
    func encodeAndDecodeUUID() async throws {
        let uuid = try #require(UUID(uuidString: "c0bdd551-0684-4f34-a72e-ed553b4c9732"))
        let multipart = """
            ---\r
            Content-Disposition: form-data\r
            \r
            \(uuid.uuidString)\r
            -----\r\n
            """

        #expect(try FormDataEncoder().encode(uuid, boundary: "-") == multipart)
        #expect(try FormDataDecoder().decode(UUID.self, from: multipart, boundary: "-") == uuid)
    }

    // https://github.com/vapor/multipart-kit/issues/65
    @Test("Encoding and Decoding Non-Multipart Part Convertible Codable Types")
    func encodeAndDecodeNonMultipartPartConvertibleCodableTypes() async throws {
        enum License: String, Codable, CaseIterable, Equatable {
            case dme1
        }
        let license = License.dme1
        let multipart = """
            ---\r
            Content-Disposition: form-data\r
            \r
            \(license.rawValue)\r
            -----\r\n
            """
        #expect(try FormDataEncoder().encode(license, boundary: "-") == multipart)
        #expect(try FormDataDecoder().decode(License.self, from: multipart, boundary: "-") == license)
    }

    @Test("Encoding and Decoding Data Types")
    func codeDataTypes() async throws {
        struct AllTypes: Codable, Equatable {
            let string: String
            let int: Int, int8: Int8, int16: Int16, int32: Int32, int64: Int64
            let uint: UInt, uint8: UInt8, uint16: UInt16, uint32: UInt32, uint64: UInt64
            let float: Float, double: Double
            let bool: Bool
            let data: Data, url: URL
        }
        let value = AllTypes(
            string: "string",
            int: 1, int8: 2, int16: 3, int32: 4, int64: 5,
            uint: 6, uint8: 7, uint16: 8, uint32: 9, uint64: 0,
            float: 1.0, double: -1.0,
            bool: false,
            data: .init([.init(ascii: "A")]), url: .init(string: "https://apple.com/")!
        )
        let multipart = """
            ---\r
            Content-Disposition: form-data; name="string"\r
            \r
            string\r
            ---\r
            Content-Disposition: form-data; name="int"\r
            \r
            1\r
            ---\r
            Content-Disposition: form-data; name="int8"\r
            \r
            2\r
            ---\r
            Content-Disposition: form-data; name="int16"\r
            \r
            3\r
            ---\r
            Content-Disposition: form-data; name="int32"\r
            \r
            4\r
            ---\r
            Content-Disposition: form-data; name="int64"\r
            \r
            5\r
            ---\r
            Content-Disposition: form-data; name="uint"\r
            \r
            6\r
            ---\r
            Content-Disposition: form-data; name="uint8"\r
            \r
            7\r
            ---\r
            Content-Disposition: form-data; name="uint16"\r
            \r
            8\r
            ---\r
            Content-Disposition: form-data; name="uint32"\r
            \r
            9\r
            ---\r
            Content-Disposition: form-data; name="uint64"\r
            \r
            0\r
            ---\r
            Content-Disposition: form-data; name="float"\r
            \r
            1.0\r
            ---\r
            Content-Disposition: form-data; name="double"\r
            \r
            -1.0\r
            ---\r
            Content-Disposition: form-data; name="bool"\r
            \r
            false\r
            ---\r
            Content-Disposition: form-data; name="data"\r
            \r
            A\r
            ---\r
            Content-Disposition: form-data; name="url"\r
            \r
            https://apple.com/\r
            -----\r\n
            """

        #expect(try FormDataEncoder().encode(value, boundary: "-") == multipart)
        #expect(try FormDataDecoder().decode(AllTypes.self, from: multipart, boundary: "-") == value)
    }
}
