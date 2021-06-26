import XCTest
import MultipartKit

class MultipartTests: XCTestCase {
    let named = """
    test123
    aijdisadi>SDASD<a|

    """

    let multinamed = """
    test123
    aijdisadi>dwekqie4u219034u129e0wque90qjsd90asffs


    SDASD<a|

    """

    func testBasics() throws {
        let data = """
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="test"\r
        \r
        eqw-dd-sa----123;1[234\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="named"; filename=""\r
        \r
        \(named)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="multinamed[]"; filename=""\r
        \r
        \(multinamed)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r\n
        """

        let parts = try MultipartParserOutputReceiver
            .collectOutput(data, boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn")
            .parts

        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts.firstPart(named: "test")?.body.string, "eqw-dd-sa----123;1[234")
        XCTAssertEqual(parts.firstPart(named: "named")?.body.string, named)
        XCTAssertEqual(parts.firstPart(named: "multinamed[]")?.body.string, multinamed)

        let serialized = try MultipartSerializer().serialize(parts: parts, boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn")
        XCTAssertEqual(serialized, data)
    }
    
    func testNonAsciiHeader() throws {
        let filename = "Non-ASCII filé namé.txt"
        let data = """
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="test"; filename="\(filename)"\r
        \r
        eqw-dd-sa----123;1[234\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r\n
        """

        let parts = try MultipartParserOutputReceiver
            .collectOutput(data, boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn")
            .parts

        let contentDisposition = parts.firstPart(named: "test")!.headers
            .first(name: "Content-Disposition")!
        XCTAssert(contentDisposition.contains(filename))
    }

    func testMultifile() throws {
        let data = """
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="test"\r
        \r
        eqw-dd-sa----123;1[234\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="multinamed[]"; filename=""\r
        \r
        \(named)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn\r
        Content-Disposition: form-data; name="multinamed[]"; filename=""\r
        \r
        \(multinamed)\r
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r\n
        """

        let parts = try MultipartParserOutputReceiver
            .collectOutput(data, boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn")
            .parts

        let file = parts.firstPart(named: "multinamed[]")?.body
        XCTAssertEqual(file?.string, named)
        try XCTAssertEqual(MultipartSerializer().serialize(parts: parts, boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn"), data)
    }

    func testFormDataEncoder() throws {
        struct Foo: Encodable {
            var string: String
            var int: Int
            var double: Double
            var array: [Int]
            var bool: Bool
        }
        let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3], bool: true)
        let data = try FormDataEncoder().encode(a, boundary: "hello")
        XCTAssertEqual(data, """
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
        """)
    }

    func testFormDataDecoderW3() throws {
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
            var sometext: String
            var files: String
        }

        let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "12345")
        XCTAssertEqual(foo.sometext, "some text sent via post...")
        XCTAssert(foo.files.contains("picture.jpg"))
    }

    func testFormDataDecoderW3Streaming() throws {
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

        let expected = [
            MultipartPart(
                headers: ["Content-Disposition": "form-data; name=\"sometext\""],
                body: "some text sent via post..."
            ),
            MultipartPart(
                headers: ["Content-Disposition": "form-data; name=\"files\"", "Content-Type": "multipart/mixed; boundary=abcde"],
                body: "--abcde\r\nContent-Disposition: file; file=\"picture.jpg\"\r\n\r\ncontent of jpg...\r\n--abcde\r\nContent-Disposition: file; file=\"test.py\"\r\n\r\ncontent of test.py file ....\r\n--abcde--"
            )
        ]

        struct Foo: Decodable {
            var sometext: String
            var files: String
        }

        for i in 1..<data.count {
            let parser = MultipartParser(boundary: "12345")
            let output = MultipartParserOutputReceiver()
            output.setUp(with: parser)

            for chunk in data.chunked(by: i) {
                try parser.execute(.init(chunk))
            }

            XCTAssertEqual(output.parts, expected)
        }
    }

    func testFormDataDecoderMultiple() throws {
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
        XCTAssertEqual(foo.string, "string")
        XCTAssertEqual(foo.int, 42)
        XCTAssertEqual(foo.double, 3.14)
        XCTAssertEqual(foo.array, [1, 2, 3])
        XCTAssertEqual(foo.bool, true)
    }

    func testDocBlocks() throws {
        do {
            /// Content-Type: multipart/form-data; boundary=123
            let data = """
            --123\r
            \r
            foo\r
            --123--\r\n
            """
            let parts = try MultipartParserOutputReceiver
                .collectOutput(data, boundary: "123")
                .parts

            XCTAssertEqual(parts.count, 1)
        }
        do {
            let part = MultipartPart(body: "foo")
            let data = try MultipartSerializer().serialize(parts: [part], boundary: "123")
            XCTAssertEqual(data, "--123\r\n\r\nfoo\r\n--123--\r\n")
        }
    }

    func testFormDataDecoderMultipleWithMissingData() {
        /// Content-Type: multipart/form-data; boundary=hello
        let data = """
        --hello\r
        Content-Disposition: form-data; name="link"\r
        \r
        https://google.com\r
        --hello--\r\n
        """

        struct Foo: Decodable {
            var link: URL
        }

        XCTAssertThrowsError(try FormDataDecoder().decode(Foo.self, from: data, boundary: "hello")) { error in
            guard case let DecodingError.typeMismatch(_, context) = error else {
                XCTFail("Was expecting an error of type DecodingError.typeMismatch")
                return
            }
            XCTAssertEqual(context.codingPath.map(\.stringValue), ["link"])
        }
    }

    func testAllowedHeaderFieldNameCharacters() {
        let disallowedASCIICodes: [Int] = (0...127).compactMap {
            let parser = MultipartParser(boundary: "-")
            let body: String = """
            ---\r
            a\(Unicode.Scalar($0)!): b\r
            \r
            c\r
            ---\r\n
            """
            do {
                try parser.execute(body)
                return nil
            } catch {
                return $0
            }
        }
        let expectedDisallowedASCIICodes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34, 40, 41, 44, 47, 59, 60, 61, 62, 63, 64, 91, 92, 93, 123, 125, 127]
        XCTAssertEqual(disallowedASCIICodes, expectedDisallowedASCIICodes)
    }

    func testPreamble() throws {
        let dataWithPreamble = """
        preamble\r
        ---\r
        \r
        body
        """

        let output = try MultipartParserOutputReceiver.collectOutput( dataWithPreamble, boundary: "-")
        XCTAssertEqual(output.body.string, "body")

        let dataWithoutPreamble = """
        ---\r
        \r
        body
        """

        let output2 = try MultipartParserOutputReceiver.collectOutput(dataWithoutPreamble, boundary: "-")
        XCTAssertEqual(output2.body.string, "body")
    }

    func testBodyClose() throws {
        // this tests handling a "false start" for the closing boundary of a body
        let data = """
        ---\r
        \r
        body\r
        -\r
        ---\r
        """

        let output = try MultipartParserOutputReceiver.collectOutput(data, boundary: "-")
        XCTAssertEqual(output.parts.count, 1)
    }

    func testPerformance() throws {
        let testSize: Int
        #if DEBUG
            #warning("Performance test results in debug configuration are not a good indicator for performance in release configuration.")
            testSize = 100_000
        #else
            testSize = 100_000_000
        #endif

        var buf = ByteBuffer(string: "---\r\n\r\n")
        buf.writeRepeatingByte(.init(ascii: "a"), count: testSize)
        buf.writeString("\r\n-----\r\n")

        measure {
            do {
                let receiver = try MultipartParserOutputReceiver.collectOutput(buf, boundary: "-")
                XCTAssertEqual(receiver.parts[0].body.readableBytes, testSize)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testNestedEncode() throws {
        struct Foo: Encodable {
            struct Bar: Encodable {
                let bazs: [Int]
            }
            let bar: Bar
            let bars: [Bar]
        }

        let encoder = FormDataEncoder()
        let data = try encoder.encode(Foo(bar: .init(bazs: [1, 11]), bars: [.init(bazs: [2, 22]), .init(bazs: [3, 33])]), boundary: "-")
        let expected = """
        ---\r
        Content-Disposition: form-data; name="bar[bazs][]"\r
        \r
        1\r
        ---\r
        Content-Disposition: form-data; name="bar[bazs][]"\r
        \r
        11\r
        ---\r
        Content-Disposition: form-data; name="bars[0][bazs][]"\r
        \r
        2\r
        ---\r
        Content-Disposition: form-data; name="bars[0][bazs][]"\r
        \r
        22\r
        ---\r
        Content-Disposition: form-data; name="bars[1][bazs][]"\r
        \r
        3\r
        ---\r
        Content-Disposition: form-data; name="bars[1][bazs][]"\r
        \r
        33\r
        -----\r\n
        """

        XCTAssertEqual(data, expected)
    }
    
    func testNestedDecode() throws {
        struct Formdata: Decodable, Equatable {
            struct NestedFormdata: Decodable, Equatable {
                struct AnotherNestedFormdata: Decodable, Equatable {
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

        let data = """
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][int]"\r
        \r
        1\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][string]"\r
        \r
        1\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][strings][]"\r
        \r
        2\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][strings][]"\r
        \r
        3\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdata][int]"\r
        \r
        4\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdata][string]"\r
        \r
        5\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdata][strings][]"\r
        \r
        6\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdata][strings][]"\r
        \r
        7\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdataList][][int]"\r
        \r
        10\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdataList][][string]"\r
        \r
        11\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdataList][][strings][]"\r
        \r
        12\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdataList][][strings][]"\r
        \r
        13\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdataList][][int]"\r
        \r
        20\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdataList][][string]"\r
        \r
        21\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdataList][][strings][]"\r
        \r
        22\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[][anotherNestedFormdataList][][strings][]"\r
        \r
        33\r
        -----\r
        """

        let decoder = FormDataDecoder()
        let formdata = try decoder.decode(Formdata.self, from: data, boundary: "-")

        XCTAssertEqual(formdata, Formdata(nestedFormdata: [
            .init(int: "1",
                  string: 1,
                  strings: ["2", "3"],
                  anotherNestedFormdata: .init(int: 4, string: "5", strings: ["6", "7"]),
                  anotherNestedFormdataList: [
                    .init(int: 10, string: "11", strings: ["12", "13"]),
                    .init(int: 20, string: "21", strings: ["22", "33"])
                  ])
        ]))
    }
    
    func testNestedDecodeWithIndices() throws {
        struct Formdata: Decodable, Equatable {
            struct NestedFormdata: Decodable, Equatable {
                struct AnotherNestedFormdata: Decodable, Equatable {
                    let strings: [String]
                }
                let int: String
                let anotherNestedFormdataList: [AnotherNestedFormdata]
            }
            let nestedFormdata: [NestedFormdata]
        }

        let data = """
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[0][int]"\r
        \r
        1\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][0][strings][]"\r
        \r
        11\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][0][strings][]"\r
        \r
        12\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][1][strings][]"\r
        \r
        111\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[0][anotherNestedFormdataList][1][strings][]"\r
        \r
        112\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[1][int]"\r
        \r
        2\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[1][anotherNestedFormdataList][0][strings][]"\r
        \r
        21\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[1][anotherNestedFormdataList][0][strings][]"\r
        \r
        22\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[1][anotherNestedFormdataList][1][strings][]"\r
        \r
        211\r
        ---\r
        Content-Disposition: form-data; name="nestedFormdata[1][anotherNestedFormdataList][1][strings][]"\r
        \r
        212\r
        -----\r
        """

        let decoder = FormDataDecoder()
        let formdata = try decoder.decode(Formdata.self, from: data, boundary: "-")

        XCTAssertEqual(formdata, Formdata(nestedFormdata: [
            .init(int: "1",
                  anotherNestedFormdataList: [
                    .init(strings: ["11", "12"]),
                    .init(strings: ["111", "112"])
                  ]),
            .init(int: "2",
                  anotherNestedFormdataList: [
                    .init(strings: ["21", "22"]),
                    .init(strings: ["211", "212"])
                  ])
        ]))
    }
    
    
    func testDecodingSingleValue() throws {
        let data = """
        ---\r
        \r
        1\r
        -----\r\n
        """

        let decoder = FormDataDecoder()
        let foo = try decoder.decode(Int.self, from: data, boundary: "-")
        XCTAssertEqual(foo, 1)
    }

    func testMultiPartConvertibleTakesPrecedenceOverDecodable() throws {
        struct Foo: Decodable, MultipartPartConvertible {
            var multipart: MultipartPart? { nil }

            let success: Bool

            init(from _: Decoder) throws {
                success = false
            }
            init?(multipart: MultipartPart) {
                success = true
            }
        }

        let singleValue = """
        ---\r
        \r
        \r
        -----\r\n
        """
        let decoder = FormDataDecoder()
        let singleFoo = try decoder.decode(Foo.self, from: singleValue, boundary: "-")
        XCTAssertTrue(singleFoo.success)

        let array = """
        ---\r
        Content-Disposition: form-data; name=""\r
        \r
        \r
        -----\r\n
        """

        let fooArray = try decoder.decode([Foo].self, from: array, boundary: "-")
        XCTAssertFalse(fooArray.isEmpty)
        XCTAssertTrue(fooArray.allSatisfy(\.success))

        let keyed = """
        ---\r
        Content-Disposition: form-data; name="a"\r
        \r
        \r
        -----\r\n
        """

        let keyedFoos = try decoder.decode([String: Foo].self, from: keyed, boundary: "-")
        XCTAssertFalse(keyedFoos.isEmpty)
        XCTAssertTrue(keyedFoos.values.allSatisfy(\.success))
    }

    func testNestingDepth() throws {
        let nested = """
        ---\r
        Content-Disposition: form-data; name=a[]\r
        \r
        1\r
        -----\r\n
        """

        XCTAssertNoThrow(try FormDataDecoder(nestingDepth: 3).decode([String: [Int]].self, from: nested, boundary: "-"))
        XCTAssertThrowsError(try FormDataDecoder(nestingDepth: 2).decode([String: [Int]].self, from: nested, boundary: "-"))
    }

    func testFailingToInitializeMultipartConvertableDoesNotCrash() throws {
        struct Foo: MultipartPartConvertible, Decodable {
            init?(multipart: MultipartPart) { nil }
            var multipart: MultipartPart? { nil }
        }

        let input = """
        ---\r
        \r
        \r
        null\r
        -----\r\n
        """
        XCTAssertThrowsError(try FormDataDecoder().decode(Foo.self, from: input, boundary: "-"))
    }

    func testEncodingAndDecodingUUID() throws {
        let uuid = try XCTUnwrap(UUID(uuidString: "c0bdd551-0684-4f34-a72e-ed553b4c9732"))
        let multipart = """
        ---\r
        Content-Disposition: form-data\r
        \r
        \(uuid.uuidString)\r
        -----\r\n
        """

        XCTAssertEqual(try FormDataEncoder().encode(uuid, boundary: "-"), multipart)
        XCTAssertEqual(try FormDataDecoder().decode(UUID.self, from: multipart, boundary: "-"), uuid)
    }

    // https://github.com/vapor/multipart-kit/issues/65
    func testEncodingAndDecodingNonMultipartPartConvertibleCodableTypes() throws {
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
        XCTAssertEqual(try FormDataEncoder().encode(license, boundary: "-"), multipart)
        XCTAssertEqual(try FormDataDecoder().decode(License.self, from: multipart, boundary: "-"), license)
    }
}

// https://stackoverflow.com/a/54524110/1041105
private extension Collection {
    func chunked(by maxLength: Int) -> [SubSequence] {
        precondition(maxLength > 0, "groups must be greater than zero")
        var start = startIndex
        return stride(from: 0, to: count, by: maxLength).map { _ in
            let end = index(start, offsetBy: maxLength, limitedBy: endIndex) ?? endIndex
            defer { start = end }
            return self[start..<end]
        }
    }
}

extension ByteBuffer {
    var string: String {
        String(buffer: self)
    }
}

private class MultipartParserOutputReceiver {
    var parts: [MultipartPart] = []
    var headers: HTTPHeaders = [:]
    var body: ByteBuffer = ByteBuffer()

    static func collectOutput(_ data: String, boundary: String) throws -> MultipartParserOutputReceiver {
        try collectOutput(ByteBuffer(string: data), boundary: boundary)
    }

    static func collectOutput(_ data: ByteBuffer, boundary: String) throws -> MultipartParserOutputReceiver {
        let output = MultipartParserOutputReceiver()
        let parser = MultipartParser(boundary: boundary)
        output.setUp(with: parser)
        try parser.execute(data)
        return output
    }

    func setUp(with parser: MultipartParser) {
        parser.onHeader = { (field, value) in
            self.headers.replaceOrAdd(name: field, value: value)
        }
        parser.onBody = { new in
            self.body.writeBuffer(&new)
        }
        parser.onPartComplete = {
            let part = MultipartPart(headers: self.headers, body: self.body)
            self.headers = [:]
            self.body = ByteBuffer()
            self.parts.append(part)
        }
    }
}
