#if canImport(Testing)
import MultipartKit
import Testing

@Suite("Form Data Decoding Tests")
struct FormDataDecodingTests {
    @Test("W3 Form Data Decoding")
    func formDataDecoderW3() throws {
        /// Content-Type: multipart/form-data; boundary=12345
        let data = """
            --12345\r
            Content-Disposition: form-data; name="sometext"\r
            \r
            some text sent via post...\r
            --12345\r
            Content-Disposition: form-data; name="files"\r
            Content-Type: multipart/mixed; boundary=abcde\r
            \r
            --abcde\r
            Content-Disposition: file; file="picture.jpg"\r
            \r
            content of jpg...\r
            --abcde\r
            Content-Disposition: file; file="test.py"\r
            \r
            content of test.py file ....\r
            --abcde--\r
            --12345--\r\n
            """

        struct Foo: Decodable {
            let sometext: String
            let files: String
        }

        let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "12345")
        #expect(foo.sometext == "some text sent via post...")
        #expect(foo.files.contains("picture.jpg"))
    }

    @Test("Optional Decoding")
    func decodeOptional() throws {
        struct Bar: Decodable {
            struct Foo: Decodable {
                let int: Int?
            }
            let foo: Foo?
        }
        let data = """
            ---\r
            Content-Disposition: form-data; name="foo[int]"\r
            \r
            1\r
            -----\r\n
            """

        let decoder = FormDataDecoder()
        let bar = try decoder.decode(Bar?.self, from: data, boundary: "-")
        #expect(bar?.foo?.int == 1)
    }

    @Test("Decode Multiple Items")
    func formDataDecoderMultiple() throws {
        /// Content-Type: multipart/form-data; boundary=12345
        let data = """
            --hello\r
            Content-Disposition: form-data; name="string"\r
            \r
            string\r
            --hello\r
            Content-Disposition: form-data; name="int"\r
            \r
            42\r
            --hello\r
            Content-Disposition: form-data; name="double"\r
            \r
            3.14\r
            --hello\r
            Content-Disposition: form-data; name="array[]"\r
            \r
            1\r
            --hello\r
            Content-Disposition: form-data; name="array[]"\r
            \r
            2\r
            --hello\r
            Content-Disposition: form-data; name="array[]"\r
            \r
            3\r
            --hello\r
            Content-Disposition: form-data; name="bool"\r
            \r
            true\r
            --hello--\r\n
            """

        struct Foo: Decodable {
            var string: String
            var int: Int
            var double: Double
            var array: [Int]
            var bool: Bool
        }

        let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "hello")
        #expect(foo.string == "string")
        #expect(foo.int == 42)
        #expect(foo.double == 3.14)
        #expect(foo.array == [1, 2, 3])
        #expect(foo.bool == true)
    }

    @Test("Decode Multiple Items with Missing Data")
    func formDataDecoderMultipleWithMissingData() throws {
        /// Content-Type: multipart/form-data; boundary=hello
        let data = """
            --hello\r
            Content-Disposition: form-data; name="link"\r
            \r
            https://google.com\r
            --hello--\r\n
            """

        struct Foo: Decodable {
            struct Bar: Decodable {
                var relative: String
                var base: String?
            }
            var link: Bar
        }

        #expect {
            try FormDataDecoder().decode(Foo.self, from: data, boundary: "hello")
        } throws: { error in
            guard let error = error as? DecodingError else {
                Issue.record("Was expecting an error of type DecodingError")
                return false
            }
            guard case DecodingError.typeMismatch(_, let context) = error else {
                Issue.record("Was expecting an error of type DecodingError.typeMismatch")
                return false
            }
            return context.codingPath.map(\.stringValue) == ["link"]
        }
    }

    @Test("Nested Decode")
    func nestedDecode() throws {
        struct FormData: Decodable, Equatable {
            struct NestedFormData: Decodable, Equatable {
                struct AnotherNestedFormData: Decodable, Equatable {
                    let int: Int
                    let string: String
                    let strings: [String]
                }
                let int: String
                let string: Int
                let strings: [String]
                let anotherNestedFormData: AnotherNestedFormData
                let anotherNestedFormDataList: [AnotherNestedFormData]
            }
            let nestedFormData: [NestedFormData]
        }

        let data = """
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][int]"\r
            \r
            1\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][string]"\r
            \r
            1\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][strings][0]"\r
            \r
            2\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][strings][1]"\r
            \r
            3\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormData][int]"\r
            \r
            4\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormData][string]"\r
            \r
            5\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormData][strings][0]"\r
            \r
            6\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormData][strings][1]"\r
            \r
            7\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormDataList][0][int]"\r
            \r
            10\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormDataList][0][string]"\r
            \r
            11\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormDataList][0][strings][0]"\r
            \r
            12\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormDataList][0][strings][1]"\r
            \r
            13\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormDataList][1][int]"\r
            \r
            20\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormDataList][1][string]"\r
            \r
            21\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormDataList][1][strings][0]"\r
            \r
            22\r
            ---\r
            Content-Disposition: form-data; name="nestedFormData[0][anotherNestedFormDataList][1][strings][1]"\r
            \r
            33\r
            -----\r\n
            """

        let decoder = FormDataDecoder()
        let formData = try decoder.decode(FormData.self, from: data, boundary: "-")

        #expect(
            formData
                == FormData(
                    nestedFormData: [
                        .init(
                            int: "1",
                            string: 1,
                            strings: ["2", "3"],
                            anotherNestedFormData: .init(int: 4, string: "5", strings: ["6", "7"]),
                            anotherNestedFormDataList: [
                                .init(int: 10, string: "11", strings: ["12", "13"]),
                                .init(int: 20, string: "21", strings: ["22", "33"]),
                            ]
                        )
                    ]
                )
        )
    }

    @Test("Decoding Single Value")
    func decodingSingleValue() throws {
        let data = """
            ---\r
            Content-Disposition: form-data;\r
            \r
            1\r
            -----\r\n
            """

        let decoder = FormDataDecoder()
        let foo = try decoder.decode(Int.self, from: data, boundary: "-")
        #expect(foo == 1)
    }

    @Test("Nesting Depth")
    func nestingDepth() throws {
        let nested = """
            ---\r
            Content-Disposition: form-data; name=a[]\r
            \r
            1\r
            -----\r\n
            """

        #expect(throws: Never.self) {
            try FormDataDecoder(nestingDepth: 3).decode([String: [Int]].self, from: nested, boundary: "-")
        }

        #expect(throws: (any Error).self) {
            try FormDataDecoder(nestingDepth: 2).decode([String: [Int]].self, from: nested, boundary: "-")
        }
    }

    @Test("Decoding Incorrectly Nested Data")
    func incorrectlyNestedData() throws {
        struct TestData: Codable {
            var x: String
        }

        let multipart = """
            ---\r
            Content-Disposition: form-data; name="x[not-present]"\r
            \r
            foo\r
            -----\r
            """
        #expect(throws: (any Error).self) {
            try FormDataDecoder().decode(TestData.self, from: multipart, boundary: "-")
        }
    }

    @Test("Decoding with key containing square bracket", .bug("https://github.com/vapor/multipart-kit/issues/123"))
    func decodeWithKeyContainingBracket() async throws {
        struct HasADict: Codable, Equatable {
            var hints: [String: String]
        }

        // The parser interprets this as a nested form data key,
        // but it should simply be a key with an open square bracket as character
        let foo = HasADict(hints: ["f]o[o-": "bar"])
        let serializedFoo = try FormDataEncoder().encode(foo, boundary: "hello")
        #expect(
            serializedFoo == """
                --hello\r
                Content-Disposition: form-data; name="hints[f]o[o-]"\r
                \r
                bar\r
                --hello--\r\n
                """
        )

        let deserializedFoo = try FormDataDecoder().decode(HasADict.self, from: serializedFoo, boundary: "hello")
        #expect(deserializedFoo == foo)

        let bar = HasADict(hints: ["foo[": "bar"])
        let serializedBar = try FormDataEncoder().encode(bar, boundary: "hello")
        #expect(
            serializedBar == """
                --hello\r
                Content-Disposition: form-data; name="hints[foo[]"\r
                \r
                bar\r
                --hello--\r\n
                """
        )

        let deserializedBar = try FormDataDecoder().decode(HasADict.self, from: serializedBar, boundary: "hello")
        #expect(deserializedBar == bar)
    }

    @Test("Decode simil-Vapor File type")
    func decodeSimilVaporFileType() async throws {
        struct User: Codable {
            var name: String
            var age: Int
            var image: File
        }

        let user = User(
            name: "Vapor",
            age: 4,
            image: File(filename: "droplet.png", data: Array("<contents of image>".utf8)))

        let message = ArraySlice(
            """
            --helloBoundary\r
            Content-Disposition: form-data; name="name"\r
            \r
            Vapor\r
            --helloBoundary\r
            Content-Disposition: form-data; name="age"\r
            \r
            4\r
            --helloBoundary\r
            Content-Disposition: form-data; filename="droplet.png"; name="image"\r
            \r
            <contents of image>\r
            --helloBoundary--\r\n
            """.utf8)

        let decoded = try FormDataDecoder().decode(User.self, from: message, boundary: "helloBoundary")

        #expect(decoded.name == user.name)
        #expect(decoded.age == user.age)
        #expect(decoded.image == user.image)
    }
}
#endif  // canImport(Testing)
