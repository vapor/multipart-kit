import Multipart
import XCTest

class MultipartDatesTests: XCTestCase {
    
    func testFormDataEncoderWithDateAsDouble() throws {
        Date.useISO8601ForMultipart = false
        
        struct Foo: Encodable {
            var string: String
            var int: Int
            var double: Double
            var array: [Int]
            var bool: Bool
            var date: Date
        }
        let timeInterval = 1571392115.0
        let date = Date(timeIntervalSince1970: timeInterval)
        let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3], bool: true, date: date)
        let data = try FormDataEncoder().encode(a, boundary: "hello")
        XCTAssertEqual(data.utf8, """
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
        --hello\r
        Content-Disposition: form-data; name=\"date\"\r
        \r
        \(timeInterval)\r
        --hello--\r\n
        """)
        
        Date.useISO8601ForMultipart = true
    }
    
    static let allTests = [
        ("testFormDataEncoderWithDateAsDouble", testFormDataEncoderWithDateAsDouble),
    ]
}
