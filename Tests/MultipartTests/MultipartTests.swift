import Multipart
import XCTest

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
        let string = """
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
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r
        
        """
        
        let data = Data(string.utf8)
        
        let parts = try MultipartParser().parse(data: data, boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn")
        
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts.firstPart(named: "test")?.data.utf8, "eqw-dd-sa----123;1[234")
        XCTAssertEqual(parts.firstPart(named: "named")?.data.utf8, named)
        XCTAssertEqual(parts.firstPart(named: "multinamed[]")?.data.utf8, multinamed)

        let a = try String(data: MultipartSerializer().serialize(parts: parts, boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn"), encoding: .ascii)
        XCTAssertEqual(a, string)
    }

    func testMultifile() throws {
        let string = """
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
        ------WebKitFormBoundaryPVOZifB9OqEwP2fn--\r
        
        """
        
        let data = Data(string.utf8)
        
        let parts = try MultipartParser().parse(data: data, boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn")
        let file = parts.firstPart(named: "multinamed[]")?.data.utf8
        XCTAssertEqual(file, named)
        try XCTAssertEqual(MultipartSerializer().serialize(parts: parts, boundary: "----WebKitFormBoundaryPVOZifB9OqEwP2fn"), data)
    }

    func testFormDataEncoder() throws {
        struct Foo: Encodable {
            var string: String
            var int: Int
            var double: Double
            var array: [Int]
        }
        let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
        let data = try FormDataEncoder().encode(a, boundary: "hello")
        XCTAssertEqual(data.utf8, """
        --hello\r
        Content-Disposition: form-data; name=string\r
        \r
        a\r
        --hello\r
        Content-Disposition: form-data; name=int\r
        \r
        42\r
        --hello\r
        Content-Disposition: form-data; name=double\r
        \r
        3.14\r
        --hello\r
        Content-Disposition: form-data; name=array[]\r
        \r
        1\r
        --hello\r
        Content-Disposition: form-data; name=array[]\r
        \r
        2\r
        --hello\r
        Content-Disposition: form-data; name=array[]\r
        \r
        3\r
        --hello--\r

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
        --12345--\r

        """

        struct Foo: Decodable {
            var sometext: String
            var files: String
        }

        let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "12345")
        XCTAssertEqual(foo.sometext, "some text sent via post...")
        XCTAssert(foo.files.contains("picture.jpg"))
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
        --hello--\r

        """

        struct Foo: Decodable {
            var string: String
            var int: Int
            var double: Double
            var array: [Int]
        }

        let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "hello")
        XCTAssertEqual(foo.string, "string")
        XCTAssertEqual(foo.int, 42)
        XCTAssertEqual(foo.double, 3.14)
        XCTAssertEqual(foo.array, [1, 2, 3])
    }

    func testFormDataDecoderFile() throws {
        /// Content-Type: multipart/form-data; boundary=12345
        let data = """
        --hello\r
        Content-Disposition: form-data; name="file"; filename=foo.txt\r
        \r
        string\r
        --hello--\r

        """

        struct Foo: Decodable {
            var file: File
        }

        let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "hello")
        XCTAssertEqual(foo.file.data.utf8, "string")
        XCTAssertEqual(foo.file.filename, "foo.txt")
        XCTAssertEqual(foo.file.contentType, MediaType.plainText)
        XCTAssertEqual(foo.file.ext, "txt")
    }

    func testDocBlocks() throws {
        do {
            /// Content-Type: multipart/form-data; boundary=123
            let data = """
            --123\r
            \r
            foo\r
            --123--\r

            """
            let parts = try MultipartParser().parse(data: data, boundary: "123")
            XCTAssertEqual(parts.count, 1)
        }
        do {
            let part = MultipartPart(data: "foo")
            let data = try MultipartSerializer().serialize(parts: [part], boundary: "123")
            XCTAssertEqual(data.utf8, "--123\r\n\r\nfoo\r\n--123--\r\n")
        }
    }

    func testMultipleFile() throws {
        struct UserFiles: Decodable {
            var upload: [File]
        }

        /// Content-Type: multipart/form-data; boundary=123
        let data = """
        --123\r
        Content-Disposition: form-data; name="upload[]"; filename=foo1.txt\r
        \r
        upload1\r
        --123\r
        Content-Disposition: form-data; name="upload[]"; filename=foo2.txt\r
        \r
        upload2\r
        --123\r
        Content-Disposition: form-data; name="upload[]"; filename=foo3.txt\r
        \r
        upload3\r
        --123--\r

        """

        let files = try FormDataDecoder().decode(UserFiles.self, from: data, boundary: "123")
        XCTAssertEqual(files.upload.count, 3)
    }
    
    static let allTests = [
        ("testBasics", testBasics),
        ("testMultifile", testMultifile),
        ("testFormDataEncoder", testFormDataEncoder),
        ("testFormDataDecoderW3", testFormDataDecoderW3),
        ("testFormDataDecoderMultiple", testFormDataDecoderMultiple),
        ("testFormDataDecoderFile", testFormDataDecoderFile),
        ("testDocBlocks", testDocBlocks),
        ("testMultipleFile", testMultipleFile)
    ]
}

extension Data {
    var utf8: String? {
        return String(data: self, encoding: .utf8)
    }
}
