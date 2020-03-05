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
            var bool: Bool
            var date: Date
        }
        let date = Date(timeIntervalSince1970: 1571392115)
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
        2019-10-18T09:48:35Z\r
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
        --hello\r
        Content-Disposition: form-data; name="bool"\r
        \r
        true\r
        --hello--\r
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

    func testTwilioFile() throws {
        struct TwilioFaxResponse: Decodable {
            let id: String
            let to: String
            let from: String
            let status: String
            let file: File

            enum CodingKeys: String, CodingKey {
                case id = "FaxSid"
                case to = "To"
                case from = "From"
                case status = "FaxStatus"
                case file = "Media"
            }
        }

        /// Content-Type: multipart/form-data; boundary=MYPsmgtObKQUblaq4QCe96cd
        let base64EncodedContent = "LS1NWVBzbWd0T2JLUVVibGFxNFFDZTk2Y2QNCkNvbnRlbnQtVHlwZTogdGV4dC9wbGFpbjsgY2hhcnNldD1VVEYtOA0KQ29udGVudC1EaXNwb3NpdGlvbjogZm9ybS1kYXRhOyBuYW1lPSJOdW1QYWdlcyINCg0KMQ0KLS1NWVBzbWd0T2JLUVVibGFxNFFDZTk2Y2QNCkNvbnRlbnQtVHlwZTogdGV4dC9wbGFpbjsgY2hhcnNldD1VVEYtOA0KQ29udGVudC1EaXNwb3NpdGlvbjogZm9ybS1kYXRhOyBuYW1lPSJCaXRSYXRlIg0KDQoxNDQwMA0KLS1NWVBzbWd0T2JLUVVibGFxNFFDZTk2Y2QNCkNvbnRlbnQtVHlwZTogdGV4dC9wbGFpbjsgY2hhcnNldD1VVEYtOA0KQ29udGVudC1EaXNwb3NpdGlvbjogZm9ybS1kYXRhOyBuYW1lPSJSZXNvbHV0aW9uIg0KDQpzdGFuZGFyZA0KLS1NWVBzbWd0T2JLUVVibGFxNFFDZTk2Y2QNCkNvbnRlbnQtVHlwZTogdGV4dC9wbGFpbjsgY2hhcnNldD1VVEYtOA0KQ29udGVudC1EaXNwb3NpdGlvbjogZm9ybS1kYXRhOyBuYW1lPSJGYXhTaWQiDQoNCkZYMGZlYzM5N2E2ZGMxMTZjZWI2ZGU0ZTI1ZjliMjI1ODMNCi0tTVlQc21ndE9iS1FVYmxhcTRRQ2U5NmNkDQpDb250ZW50LVR5cGU6IGFwcGxpY2F0aW9uL3BkZg0KQ29udGVudC1EaXNwb3NpdGlvbjogZm9ybS1kYXRhOyBmaWxlbmFtZT0iZmF4X0ZYMGZlYzM5N2E2ZGMxMTZjZWI2ZGU0ZTI1ZjliMjI1ODNfQUNkMjcwNDM0NGU4MzdhYWMxMjRhOGRiZjUxZWVlYTQ4NS5wZGYiOyBuYW1lPSJNZWRpYSINCg0KJVBERi0xLjEgCiXi48/TCjEgMCBvYmoKPDwgCi9UeXBlIC9DYXRhbG9nIAovUGFnZXMgMyAwIFIgCj4+CmVuZG9iagoyIDAgb2JqCjw8IAovQ3JlYXRpb25EYXRlIChEOjIwMjAwMzA0MDYxNzM5KQovTW9kRGF0ZSAoRDoyMDIwMDMwNDA2MTczOSkKL1Byb2R1Y2VyIChsaWJ0aWZmIC8gdGlmZjJwZGYgLSAyMDEyMDkyMikKL0NyZWF0b3IgKFNwYW5kc3AgMjAxMTAxMjIgMDc1MDI0KQo+PiAKZW5kb2JqCjMgMCBvYmoKPDwgCi9UeXBlIC9QYWdlcyAKL0tpZHMgWyA0IDAgUiBdIAovQ291bnQgMSAKPj4gCmVuZG9iago0IDAgb2JqCjw8Ci9UeXBlIC9QYWdlIAovUGFyZW50IDMgMCBSIAovTWVkaWFCb3ggWzAuMDAwMCAwLjAwMDAgNjEyLjAwMDAgNzkyLjAwMDBdIAovQ29udGVudHMgNSAwIFIgCi9SZXNvdXJjZXMgPDwgCi9YT2JqZWN0IDw8Ci9JbTEgNyAwIFIgPj4KL1Byb2NTZXQgWyAvSW1hZ2VCIF0KPj4KPj4KZW5kb2JqCjUgMCBvYmoKPDwgCi9MZW5ndGggNiAwIFIgCiA+PgpzdHJlYW0KcSAgNjA5Ljg4MjMgMC4wMDAwIDAuMDAwMCA3NjQuODE2NCAxLjA1ODggMTMuNTkxOCBjbSAvSW0xIERvIFEKCmVuZHN0cmVhbQplbmRvYmoKNiAwIG9iago2MwplbmRvYmoKNyAwIG9iago8PCAKL0xlbmd0aCA4IDAgUiAKL1R5cGUgL1hPYmplY3QgCi9TdWJ0eXBlIC9JbWFnZSAKL05hbWUgL0ltMQovV2lkdGggMTcyOAovSGVpZ2h0IDEwNDEKL0JpdHNQZXJDb21wb25lbnQgMQovQ29sb3JTcGFjZSAvRGV2aWNlR3JheSAKL0ZpbHRlciAvQ0NJVFRGYXhEZWNvZGUgL0RlY29kZVBhcm1zIDw8IC9LIC0xIC9Db2x1bW5zIDE3MjggL1Jvd3MgMTA0MT4+CiA+PgpzdHJlYW0K//////K+ijLcwrKbYmPmQVlQju1ER///8rhaLoui6I6LoujsuidSuLouDWXR2aouBBHCm1K4mgkERjkxyxyMdBIj5HRHyOiFZHwkEWOccscSMcjcoc45Ta4rmECERERERHkdF0RZBBBMIRERERZhSuo0JhyMcjHOORjkY4jSI+RpJBMJkdEcGojhgjqVxiBCIiIiIkUcrUpzjiIiIiRjlNlbCEkOcchgc45DA5GOccgQOyOgkEEEyOyPkdEcCCOZHZHGRwXI6I44RxxEREREWR0R0XQQQQiIiIiIiJCtlYCEmOQyhyEHIEDkOOTHCCFpBBBMj5HDkdl2Rw5HyOZHDWleaCEhBxOOIiIiIiIiIiIcyJFERMOQPBsHIYHBxOiCOOccjHIxzjkMDiRjkY5xyGBzjkY5GOQg5Q5xyxzjkIOccSEHZHZHGR8jjI54iIiIkQcREWRwaSOGURwVlhHHIQcjHIQcjHIxwQISxyMc45GOWOccocRIxyEHOOJAgcSEbJZEREREREw4iIlDnHKHOOccoc45xyhzjnHERHRCDkY5GOccVWIiIiIynKHIZo5DNHcIRESGmOQIqK4qytSnIYHEXkxyEHIxyEHIxyxzjnHLHOOJxzjkY4IzReI7I4IR0XRdCDKHEhByMcjHDoREREREREITZoJFDhIoc45Y4SQTsjoj4hiIkQcryjlOVZTZLJCDkCByGqORjhHtFDhBW4jYhBWGggobI4wzjkMocEIiI0IihCVhC3tj4hwkYdEfDKHEFkY5AgcjHOORjkY5xyxzjgj6CKdPCBdlDhAsp0EU6RhwVwmki8M45Y5xzjkY5GOiPwhEREREUEwiO6ppBC0wSirCFtAirEREWaA2EdkdF0XRKEXRdEfI6Loj5HRdEfI+R0XRHyOi6Imi6I+R8joj5HyOjaLoj5HRdF0R0U+R0R8j5HRHyPkfI6LojqyhyDUOQyh1CCsofVIIE8HhBMIpyh0EEFnHCBbwzjkY5xwRHwjjiIiRjYiIiIiIiIiIaEREREREREQwQiIiIiIsjrE45GOccjHBAhIxyMcQjaBFDpDgi8nYQpQmxoRSEVxkdRERUSDOOUr4bxERERMOELSOOELSCERRQ8RDKdM44SQIqyxzjnHKHOOWOCI+xDyOsJ2WOccjHOORjljkxyxzjnHBAhOOccocIjwIIIRJxbL5dBCDNEqEaYwQIREREaDjCXQiIiIiIiIiKhBWVYQiIhkZwQiewSDshByMfDeiOoRHWUOccjHOORjkY5xyMcjHLHJjhEdRGECDKs4ZVsui6zCMIwqhqR9CPI6WNvERERERERsocMaLoQUREREWOpQ5McjHBEfb1RQ7ssc45CDkY5Y5xzjkY5Y5xzjljgiOhYIjkIm1KHCI6OI2jyMIwYJDEECE44nHGnDWOEIiIiIiIiIYibRtCEFZHMjoRFlVFDiyOMjlvUIjqyhzjlDnHOOccsc45GOccjHLHIIOCI7I+UIRMIECiIsujCMIQQJCccRyGZqUODWw3iIiIiIiIiIhkfLoREGVgIREp0EkNxOA0YUJ2WOccocmOccgQOWOccsc45xyxzjlDnHBAkkEiOiPm0kXSRGIuiOGwj5HyOiPkfI40kUPg/oRERERERERERERDTI8R8ugghHMIujCMYQiIiIjsXaQUIjrKHOOUOcc45xyMcsc45xyxzjlDnHOOUOcc45xyxzjlDnHOOccocECEIJgkkEgQLI+CBYSCCYWEEEyOiPkcIR8jsjjI+R8joj5HLlDyOlhx4iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIjcfyOgjjw1DJDlDnHOOccsc45Q5Mc45Q5xzjlDnHOOccoc45xyhzjnHKHOOcc45Q5xyhzjnHLHOOccoc45Y5xzjnHKHOOU5Q5xzjljnHLHOOccpyhzjljgiPpBDjiQ2DwnQIEIiIggQiIIEIiIiIiIiIiIiIiIiEEIiIhBCIiIiIiIiIiIiO4LYhQiOoYikQg5GOQg5Y5xyxzjnHLHLHLHCRQ5xzjlDnHSKHOOcc45Q5xyxzjnHLHOOWOWOTHOOWP7bCIKBw46OOUOcc45xyhzjnHE44IEIljiIggQiIIEIhBCIiIikIikIggQiIiIiI/TbI4ZoasRSYTSTI+R0R8JkfRQ5xzjlDnHSOOUOcc45Q4lDlDnHSOOWOEEyPkfI6Loj5HRH0ccpynSSOOUOcc45GOccoc45xzjlDnHOOUOCI+5GIIFaWE8ECEECERBAhEREREREREREECEREQQIRERERYQiIiccECERESnBAhERERERGkEFFUtQiOrERIKg6RGOJCjnHOOccIJkfI6I+R2E0Rjho45Q5xzjkY5Y5x9l0RzI4ajIZo96I6+yxzjnHLHOOUOcc45xyhzjnHKHOOccsc45xwQIRKHBAhOOUOccsc44IEIikIpCIQTCE44IEIIEKQiJQ4IEIicfERCQsIKNuwghERERERERERERKHEUkkgQJJIShzjggQlDggSRxzjiyPpI45Y6QlDljpJFjnHZH2FIZg5x0R/0UO6U45Mc45Q5McpyhzjnHLHOOWOcc45Q4IEJQ5xzjlDpCKQpAgQikCBCkIpHHBAhSFIECETjggQiKQiCBDWKQpeIRHXQQQiIiIiIiIiIiIiIiIiIiIiIiI4e3VfFlDkCBzjnHIxyxzjlDkxzjlDnHOOUOcc45xyhzjnHKHOOccpyhzjljnHKcoc45xyhzjnHKHOOccsc45xyhzjljnHOOccoc44RHUMjpwwwtEdR2Yc45GOIpHHBAhERERFIRSSEREUhEQQIUhFIRFIRSBBCKQpAgQiIiKWMj6pVGGFBiYcIJkfI6I+kkinKHOOUOcc45xyhzjggSRxwQJJI45xyrKdI45xyh0gQJI44IEkcc44IEkccp0kEccECSBAhSOOcc45Q5xzjggQ2Ie2+EHCKHKHERERFIREREREREREUhERSEREUhERERERSEQQIRSEREUiGmOER16VQiOoiGJQ5xyxyEHOOccoc45Q5xzjggQlDnHKHOOUOkcc45Q5xwQJI45xzjlDnHOOUOccpwQJI44IEkccECSOOcc45Y4IjojqQzPKcrhvKHFEdUR1HCIg5Y5xzjiIIITjlDggQikIiIiCBCIiIiIiIiIiIiIpCIiKQiIggQpDxEoBqUfjDUr64QiImHKHQRxwkkkccp0jjlOUOccoc46RxynKHKcoc45xyhzjnHKHOOU5Q53KHOOUOcc45Q6RxzjlDnHKdI45xzjlDpFOkCI+0GiOuUPHCRHUEUOEEyOyOyOCsEIiLiIsIRYQiwTiIiLCERERERERFhDTRQ496jiwkIkHHLHOOcc45Q5xzjlDnHCCspyhwghOOccIJkdEfCE44QVsjoj5HyOiPhWU5Q5xynKHOOWOcc45Q5xwgvjuihwk4RHUUU5GOccsc44hBCIiIiIiIiEEIQQiKQiEEIiIiIiIiIiIIEIiwhFke3UW3js7iIiJFHLHIxyEHCCEIITjnHSOOUOEEyOiPkfI+R0XRHZHyPkdkfI+R0R9HHKc44jd9BYahncoc45xzjkY5Y5xwgmR0EyOiPhMjoj5HwmEwmR0EwmEIsIRYQiIiEEwhEIJhCLCEREoc44Ij6XhvCcUIiIiIiKQiIiItCIpGHE44QQkQdIRSE44iO/QIj9QiOoZTkNA6RxzjlOUOU5TlDggQlDlDnHSCCE44QTCE45TlDpAgSRxzjlOU6RxynKHBBCccgg/Cu3fxR3IxwghJjhBCIiNCIiwmEIhBCIiLCEWEIiIiIiI8iEElaw3oI45Q4QQsj5HYQmHKHOOkdyhynKHKHCCYVlOEEyOiPkfI6Loj4VlOEEyOi6I6L5HRHyPkdEfI+R8jjI4yPtNEdaKHWE4hiJxzjggQiEEIiIQQiItBBCkIikwhERERERGkmEKQiIiNMwidF9RxuFCI6gynERESKOEE0FKcp8JFOUOU5Q5blOUOccpwQJRYIcREQn4fxDLHOORjnHKHJjlDnHOOEEIigQiCBJCHEQQIRFRERIxwiOsjpQwvGinERERERFlwkTjiCI5EcFWh/DDiGU5Q5xzjlDnHOOUOcc45Q5xzjnHKHCBCUOU5TpHHKcocEFZQ5xwQLKHCCEmOccsc45GOcc45Y5eoL8LaQiIiIiIiIiIuwhERFhMIREREREREJIjrqFCI6iDKHJjljnHKHOOcc45Q5xyxwgmEJxzjlOUOEEwhIIOQQchgcpwoIXnHUP7KHBAhERERERBAhEIIRxESMcQQISx2NEdKHw4xZTlDnHKHOOWOcc45xyhyx0ggmR2EcchBxMORjnHZHyOgmR8j5HTBD+FI6i0hEIIRERETjiIiIiIiIsUQWhuwq+IZx2R8jsj5HZHRHwmR8jjI4yOBBHCEcZHRdShzjkY5CDkFA5Y5xwTLHOORjnHOPlDkEHCI+jjojoGWORjnHIxwQJDDBAhEIIREREREhBxEEIiIiIiIiIiIiIiIiIiIwynKHESGdSKbJmZGiEQZxzjlDkY5GOccsc45xyhyY5GORjnHBFRF0T5HQSNo9n0XRgiPmMvns9kfJ0XRxEfOIxm8jouj2ey6PozRHR1RtENEdH0XRdG8jouiOi6I+R8jo4jaNo4i6I/EMJJCIpCIiISCGJOwghaEMJhBoREk7BCGkE4iIiIYQYQsIjgQwTCBlwUgQiIjI6iMoc45xyxzjiQg4QKKJu4uW4IjiBNlOWOUOW4iWPI6QsIjHIxynFBFjsIoe13IQck5OCUE3UmOSgocm1qCGEhESEFhS8TD7ZTu2Qg8HEMcIWaybjOIYdvuO1SKHTzjoEFFRDKc45Q5xzjlDnHIo5Q5RWpY7j5hyh0CBRyhxLcYpkcF4ljsU9YluRbhQm2sRUhWtgixERBCMtxFIm44iNhAsTjhkcQj5HcS+KHxl3UKoQRTlO6DCB0EC4aZbWQDKHOOW4Vssc44ZHcoeqKHatImPYhEdI45xyIOd5fiECcsct0hEMj9yxxFyh9oMFY6CaDI6iIjFhCexxEw5UULsMUihxixst2CEREQoZcQjxwHeyOMjiU4aYqcejjiDgyhz+EynKHCBnspwhDspwQUGEGVaFlDlOEIPCPoujaLoj4YIMocEJHSKc45TlOER0R0ihwmCCynBAyhwoRHSBF0DmmR1EEFDMOU4IwoiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI////////////MlMNB0RqBDwhHzYUuKSBS4UuFNA0QZOaCgifwi+FAwQdAgwQYIGTmqTQUEE0rpYSqknqcQhQgv1Rx2jj0ks8hpBJHHpCwxSSwgklVIJYwgvYf6SVVHk8SC0gw6SwlpJInipJAh5qQbS4hJf9IUent1SYSpJE6SEwuEErZPp9VVLhUgtQlhhggoaCVYS6RwlPFBG49ARjCPh0EfHwn5nBGMEiPiCNgYIMEZxQQqIiIiIiIiIiIiI8s4mctFgQDcspmGAw5ZVgLcsqkFbllLQrcsouFbllGgS5ZVAd5ZU4duCISQxyynCNyy2EI88shoJdyyLYjbcshKI2dmYjyyKQmdrRtyyFojYIE3BEYnBFlDlkFhXBBcERlbOzjCBNyyAY3O+IuSCblkViWEEZyDyYcshcRsILDdkQEggtG1bbnUJYIwm0tts+FiLYVQw2JNqLToLDDIoC+0kgwykAi2lTZBhDN20kgwzqZHm7aQSDDEfaQSDDbt4QQYbcNpAggw/4IEG27dAgTD7amBtvbIGogg23bCgiE3R9tiCb7ZFm72/q7ajbbI2fthlWaVsMinIQEVslQEBBWxQXO1eUFbiCudmEe+I1hBR+ZAgEGvKA2FwzwyPA05sJZBkp7Tadb5tPTbTHHUTx2tHd9L10m+Nq3pPyURqkkRw/uc7SSROfikcOqCSvwvCPxNAReCNCI+EYcMIU1EREREREcmxKBtBQRw5HDYRzI8XRHRiMZgziNFK75ZTNGvNojxHA2CREREf//////MgQNBoFz4SyCJzB0tsJQ44q36zh/v/Q+/ulw3R84IMGGCBcyS0a4YjJssZHRdHMxG8vmEbRoiPl0Z5HzREdUIiIiIiIiIiQJoaZuEH/////8mxKByBTlsmqI6I+eyOiPl0XReLixERERER//yyFxZZCY4MHLIJuDBwwcGHDDhhmTnYZ38SzI4hHGdiAeGGdmohFhTVAiVAyNhiGylDMQ4InoyTEM4jOTeed8C4YZVRe0CdFOcOpKlTJoHM22S0JmpUECxHBlFAdBF0SxBFjIYZFA6SkcPRBEuknRA3sQSCOXQbIFhGSUJ6BqSoxpLv9Ck2GCSn0aRFh2k7oER1rQTDHWkiXzYOklb0PsK2SNLtIMhNmqSeGgfuCbH9IUkDsMOU67kC0g39JKS0eRGG0PeEEE7rtJBFUNs6svsNAiP6bQkUVa4SCSCBhthJhhg0l7ZEybSDDCCQR1ahh4IE4MGl7six+xCU0IIINthGDYMV3JObDbdEm0jgqTbYILHmRaGckZICmxScQ+M+CWEG4b1EMTbUJtiF8GSnsGgz1sGCCJzDcEThtt8MUin9pP5v0w2lDwkw20E3b4pHQ1QdX8Qmwwgp3D6s9aTutxBUDB19UYdhvb1wm2gVthJwyHJUVAL+Om2Hhh/b6XhJRCCIkT5K6CbvDH0LDCW2gsrmmfIb+hYR4D3fDaVNlPGx0yLsafFHowk3h7o/sNJbDJlcW+k4QTeHDaQQYbrcUnggwQYQMEGgYIMODBggTsO0hSaiIiIiasQYgwglGJ2sg6Ck2JQWw2yPmEXy4yOiPkcMEdEcC5dEdEeI4UuZdEcy+cRdGER0YRjI+RiMI/n8wjNGES6yBdyIOUOQccpzDkGgchtjiIiIiIiIiIiIiIiIiIiIiJDIDSZxYRERESWugoShBQgoIKCBR/ldbUf///8yBM/EiPqGCMEGRRyKmCmgw4Rp/zi/uonj6SquIKMNZJ3JXHhh7nPt4pHD4bwqwgYYig1ERybEoHIFOMr6qP/////8yUhSOiNiGjIpnVm4iQpHRFKEebRWAnIEhcTiCPOQJDSex1dUnWomBTAQFI+R2cFNjLhAgy8bFSNwUjjN6ibGYjDCkdF2bFMBDd0fGGe2HFwj5R7YZ7YYTo17bDnKkgjX2nF0fmzXH7f/8l38Mf7aTYP7/f27r/+fio/hGv1sPBGv6919s/Ov+3w16/XvcMM/6vb/+c4MEGCCaYQabJjoEVYMJoODTYMjtNNg2gyLwMjtiiOoNMMlbCfEREREREREREREJCIiIiIiMt1o4///Mi0yOIR4gYpGoqIwztJEJHbxqiJxkTikZ2OyZCGjIpHWKIjCKVEViSMiIhkdk48IQeQkbjXE8UkSrOwSI+eLKw2XRt/IPEXKE7nZdESzydyFoUcZIEhcUfClQ+xyhS6PbFHsELiLvhikeMccxmnn40j8fROjiM1n8KcRhHIozPKM4jNHo/H0fiQjrH0YzTwuYRpHXz8TxCI4ifPowgp/OuoU/k/nTBHHnTNMkIKfiK5p51Wviq1qOP/4+DI8CCLwQMECMYIEYwgRjCmw5Hwnggi80R8IWCBGMwRHgQReLkRyI+FCBGMIEYwoIEYzZEfBAjEEDI8EEFQIjnBkeBAjECCCggRiBAi8XjDLghHgQReCBkeQIjmCCLwIIvJEdkcwQReBBF6RLCLwIJSdkeMMvGCI8gRHMECMZuMBAQReBBF4wEBAyOwSBTYzAQIGR2bHlEYEBAy4pgUjgubGEGXjgpgITsuECBlxmAhsQ2M2KEGYFMCmYycZcIcGbGYYQMjs4M0jAQ4KYZhnMuzgpiNxgXKBlwh4ZoEMMwy4EHBnBmB4IH4J0LDBNWggyni7PYJtrQvFmxbBPiwTBNvYqL02wV1sE6CDjBQTocIOk2gh2mawTobBYwWMLbgqdBDPlDQToIYTbBOMFW7PlBNIIMNnyDBNIIHTZ8hgnR7fs9sGCR+DDPx8PbRoYYTo/Nmu4Z7YYJNnyj5TR8hhI/NmQaHPhTnxo47R8bQYIOEfLs+UfLh0mgjX6nvo0MM+MI+Wa27TPxraPjR5nsPBgv89d8Qy7r/U9WmPwyd/wwYMvK2ux+v/NrWv770Y/wyaARH/D/z0+r34b78V7/+c/8MER////wxvrb//Ofro9PreGNk7baSK+N/j3r7DS6d7D4P/7/e62ydkif/2c8I97OYMN/7uzn2j380/8GGDD3p3R833/ueVvfYI7/9s5/k+EC/CPezn9ggV+COP/wj3/sIp319rpnP/CPf/7/8I0V31v/zy/7CKH/dYRonS6sIp55f31/vVr9BHvgjR//+v8/T8cHX6sV2gyOKXqX/2KsEU+wg/Mf65vyP12kq2EH7DTsEC9kZw020mKsJ/sV+XRH9wg8j+ECtBsVeyO3bFMNL8ECtB/sjugr/DDTDFfgin2oIp/+2gv/UIoeR/bQXX+CBMftqxt3vX5pvqwwsML+wy93t7t7DX1X6+/Xv1boxvDSMfwgRhIIugZQgEYwZxAQMrinCLpBF0gSBCDSBGEDK8IukECKsJBF0gi6QIwkEXQYKiO0EXQMJAjCQIwgZ+BIIuj+DCQRdIIuhOmDBCDK8EYSBGEgi6FBF0gRhBoMIM5wg0DO4QoEXSCLoQZjASBIIvhhAz+EXSBGEgi6EMJAjCQRdBBF9AjCBmOVwRdIIumGgQIqwwTQRdCgi6QIwggi6BhIIukEXSCLpAgioDBMNoIugwgZThF0KCLoNthgkEXSCI+DMOgRWAgYSBA1bBkdyVkcwww0wgwmGGmmgwxYTpMMGR5iGwZHaDYMjihMMQ4hMUg4hBk8FBg1CDCDiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIjMuNmGjLlX8QZQECMKIjluWsmIkkS8SqNcZGsSlkzjgQl41x2IjcVEdrUQtm4gUYiNR3qyeKoR3rkWiVxzO5lLdXkjaE17uIkCTuVjGcDlHkH4uLidMXKjEmiDij2zv8RcUe3Mi0zcbM5G4oI5keMGSEXZmwgYQeXZ8yRm8vBBmzOZePjPGeGT5fNmfZ7N5eP55nMuwQMhs5nGcjcUGeyPG3l4+ZzL5s8js2ZvNMvGbCBmECDN55n3hB5ePGEGTmeRdm2cygZxHCPPPszMxm44i+cZEM+z6MZzI6OI4jiMZpEHOcR6I6CnEYRxZfCnkfijNUfRhBT8pB5plOlEzyQik0lUYaoI9hu4RrYTI+EfDzDMYI1nsEwoZjCPbCQQZfYQR7DCDLwR7hHsMI90GR8I9hhHgMKEGXgoR4DCDLwYJ6CPZobo8BhMj4R7PQMvhHsMIYR7dl5hUEGXgj2aD4wYQUEaAwj3YKGXwjQGGEEaAwgzG1QR7QVFYwRoDwj2ez27cIWEeAwjwGEezODI83YUIGXwQIwYQIKEwgSbDCFgsMjsuzcih0R8KCBGIwZeBAjGELQIjmECMWYZiMER4EEXM0ZHggZ9l8wELmbggi8bFQMvHBTAQnZcIaClx5uNjMBDgpgZOKEDt0rfiFaGLa0r+tC2wwr42F7oUrsIMaQhwwmw6GGE+2qTfoLaFC4VoYZ8F0G2GoYTq220rxpPcLa8dhbDSSt4Y0OrDTH2fhpCk7CDbaCdhdMJJ2rGEzdhBt8bem2FoJhsxAJfCPOwT00ggwwwUK2fIeknnxsE6PjZ8tBnts2B7o9tmuEa0mj8wYK2l/k7L/PUvf/nrrWjU6XPT81P6zn+2kv4kdkf56vMfOftpfWv89P++UGR/21Xwyb+sGTj84Ot+2l/aS9hk4//+v/+GDI/H/1+HvbQQbUfVv/+c/DBEf+hR9d9h9egXVnO90v7YZv/2wRT9vYYI4/2wRTs5/T2c/2KevCBfZzemzi7OfsV9139ginf9hGjo+fYp/J9s4u6NP+zisIp3Xsf7QIJ3oG/+v//v8IFwRHf7JkdwjR8MYR7Tgin7dff+e/CBL9hArPJultBhpRcQ7ZGfbDqDYfsV9sGyOHxDimGEHbI7I72krI4rImiYaTYQcQ9iltkcWKwk0u2k5H/2R2GE8EU/0HB2EHe0waeYlZHdtIxbhPYy7ZHbS0mv0IZuhp5tPgjj9Um1yP7aXtoLwih6hFDw3+rdJa+1acMErI69L6/g0v99hhWGFdekDCEjEYQoEgQNCKBGEgRhCgQMpwRhCIgygMoMEIgyoQIJAjCEGVxSGkDCBlGClZTghBlDAVAyoCLoGEGEgSBGNAjCEzQNAynBBFWcIfgSCLpIp0ggRWAhQRfBhAwgz+EXxDiDCkdEgi6QIwkEXU/GhkOQRdMIGEDKsECKwIGeyraCLoGCQRdIEYQMIGUGgwYTQIEVh3CLpBF0gi6nHIyAgzoDLmgi6SYZeDEJtMGEmnaemDDtNgyO00wwwwwwSDmRaYiIiIiIiIiIiOIiIhBE5iIiIieMRERERERERERERLmIiIiIiIpDNQ46ERERSaSERERERERERERERERERERERSM0IiIikIiIiIiIiIiIiIiI2EExhIJBIJNMNIJkRKCiIiIiIiI5kSoiiKhEyRF0VytQmTyZTippkFiDisMnjESMmIhDBIjsqUdgTIlGuKI7BIicRWOxtnYSODIXFLjcRKINkFZSR2McyBdoRnWj70ONldDi4m92khoXJCcRKRCLndSGfZJE1buQNO7wgeXZyNjNI3l2CBmzORHi8R2XZ4ggzEeM5EcyiOETkEGXy8XjhAgeXM3mkR2ciPGCyOz3l2ewgZgjw8IM+ZuNmcjdl2eIwzmcZREeNmeM8ZzMM5nDPDBA8vH82RIM8RzLsuzmXZhm43nMvHs8Z4wQMxnjPZeOiOIuyGZxGMwi+bM+i+akXqPs8Z4jhlGXjNhAzaBSOyOjmZ5zPGSEcRiNx5GM3GbP2cR5hTzyGsvnTBT9n48swjSISOkUIEd8MFDLyo90CI+gzGDBBHw7ggTBCwQZiR7YYShHsNMxIER8I9wj5YSDI6QIj6PbDBYa0zEgQJkfR7DsxrDMShgkVgYR84YQaoI+Hu8MxhGth6CPZ5sugj2wj2wj2Goegj2GEa4YKGXgqPbCPYYR8DQZdmNBmGY3sIMvKEewwj2wwQUI9hoMvBQgzGEewwgZHGR8I9gwgyPhBl6wjwGEaA0VkI9hhBl8Eaz2CBMHBj22GEe2ChAy5l8IGXZeCPZ4BBQmEezDlDoj4R4DzDWGR4udMMIEYsECMYRCWDI+ECMMuEBAjGCBGIuRHgQQXwneDEdhetjQNViC7pNtY7BiwY0whHSH20mnGhSbSt4Tb6I7X7DSVv4WIK2qFtChaQojHTtpIjxfC3YYpCrbCabahfhhbqIhcOrbCd2tDYQMIO7CFhBvQsQsGKRHGGFdN4aVtLphiHDChWwoToWkHcVHFC8NpQg2DpQkPQtnxwVpBtmuhbWwToJ/+ff//+CNFe9/BgwYO7/26/9//56fd6/7wRo2lPVmm50W1nP/8GXN///6/gjP/f/uan//nOaIMHj6/7deGD//56fNsj3Oi2l7aXOfOf+v3PWTH+r/8wg//1/pf9L5hBs+gb67OfsP1ul/r2GCBX6sPX60lYqGb+wR3hAoZv4qGb7/fMIO2CO+vr//2ziQX7pf9Nm/t/uuzmglDdnP2/9h+CKx//9ginfoF9nPYr2H2c+zn/vX2eSPf3XB2vD0000ww0k+9iGweGGl6w6hpQ7UMlYNNq0thpenDCCTg2SsQy97QYaUXdxDaDJHbFMjgjttMUxDg7T72KYaVqn3cX9sjgQ4PbW1vtivtKzbwuxVoMj9MUu2lB+1YTv//VjbT7QdhFOK2tJ8EdxWxVwvbS6ZFo1CBfD4oECKwpwQIrAhPIUVZXhCgRhIEgQIoQCMIGEgRhIEYSBAisCBhCgRhIEYQiK0CCQIwjTQIwkCBFBhCIiKBGNAjGoMEKBGEgQRRWUClKoJFHKsIQYSBAynBAihwRhIEgQgyuKcEIigi6DBIEDKoCBlOCEGVYIGCQIwgegQJAjCEGegQgynBGEDCFBF9AjCoGdwggQYSCLpBF0gRhIECKHBGEgi6BlcCDBkdAyoDL7YMEgi6wYVBsMEDK4KR4ER8NhhBtBF0DCYYJoIukECKwGR0R1ERERERERERERERERERERKRuIiIiIiIiJnpCIiIiIiIiIiIiIiIiIiIiIiIrYiIiIiIiKQiIiIiIiIiIiIiIiIiKQhIREZ24EggmmglO1JmQGykdxERERFAo5XWIqcaopGdmrIGKdizKWzFK75BdxEOUJ59lsXmQUi+cgpHRqRfNoxhQRTy8Zs6Rmi+bR9n8zj7wmR0cZJlkeOiUj5gyhEdEOM0XzTI8bZ95xnkXjRGM5mbPrghYIEYnEvG4IMjiEebhl4Eaz0BGIIWFBGsseXIvBHs+XEEazUNZoKvZeLtJAgUQjQzDsECMQIWEyPBHs8HsmOazXCPZ3DI+EDLmXwjwwXhnwf7R7eoTxaTbP/hOwnFfSeqQYwmw2o4qDBpNhnIQMXsJ/EK0LBQWgkw/5qXf/+fX+2k7qbZH/78GTo3brOMj717znaX4Iz+/ZY/+2b9V//s5/9BBKugX7deDekw9AsIEXrr7ObQIL9BdV6BV9NioNi9Pg7Vigw0FdoSUfiGsNtJiGR6tINLEjttpWoYpCDi+Id3dxBp2YqKKARhIrgi6OqQIwhBhIEgU/tAgRQ4IwkCBFBgjCEGEIMIGEkECMZ1R9AwkCQIwhlTPoCBFEAjCQIwkCQIRQIYiIiIiIiKVCIiIiIiJwhERERFaERERERhqCDURH//////5kqAhHzMEPhCgIRwhQIRw0GBD4pHDQcBIIkeCJ0Bg3BA2gRmZpgwwz4fCXUaek63OOwjD5x2jj/nHDuu026QpN7dLtpebx28cYMT1SX3QX9euGHWwYT/7aXtrx7d4MheW39tfbS5O+GKwbG/WxXsV+cWG8nzQrZITaXXteK4a9o44YYSBtBbXteF34Ok5kSiHUYIG0CBggbQIGRw0AgYcEDlWCaiIiIiIiIiI///////////y3LFH5b2o/////////////zJSGYRgOTim8wKZikhEgNBgKbGXBycM8Eb4MEaGfIGGDBJzYTxhggYQMnxOZL9Q+EEQ+Hpwlf9vfDfXncPTHH+82nshD1HYejjv/S8TxwwfWG9Jv/CWC3Bh+fi6I7wxpN/xBWXxmQJmhbYMQnDoX/J2HT9rfUOj0e6W3iczyw6w37pN7aWGHpBA8IuICBgxCBAw4QMIMEDZCzBsGEOoiIiIiIiQ0MZN/DJAoLjlkNYniPmMuBNDERESzLz7I4ZAbxEf/lcbUf///8yLQ2EKGdixEVGQMZwytkdXn4lkqMO0HD5Vd11ThVHxSxjYnhggZwVygi5mgpoHPGZmR0SCNkYZQ8xF0YZHRm82inyhgnm8iPhGwGGXxcPDDMGCLsMIuAi6BFwDCNbbYhgjQDwxsYQIKycAwQIwKkR6IZwYIIuzoEOBDAhcjAQwMjkaBg8FPA5sQ4fW7tvpu9cVbQb8ncLeuofZO6wm5KG0mHRcNF2w0wSJww2XYZPGicNE4CRcO9L5ONfPi/Gwdfj+v/9V7BqGEtt0hdD3X2tjv8EaG/gi3hupMgO////eE/7DxrdZJHz4nVAjNW96wlS9BLhBHozmCPj/v9/9oEZP/CPbu6Yf+CLeDEFdW0oaEP0ohhCDZCQ2v2Q8WOwv4UWRX/Ydhl51aYZj+guEfUMxmyhH84ZgwR1kVxRCI5hnwJkH4KiOSaEMGTwNk3DDDLxfCYQhyGAwkIaDiEGIQYhNBg04aTDI5Ig+A0oiIiI2IzcxEREREREREOIiIiIjCCOkYj0g0EanFGphBhkJISELTCRFAzSOyPEeiIhHw42SKBESB4aTSFBER//////MkpR///mQUFMAhwIaCGBDZktDkcKTMUwi5EQREx6hJBoMINESwYIGCJagRfw4cEXxaCqFbDIPhE4joQmEWCKQQfUhHIsETCdkKUkNGpIDLOUgmLFkGCHFCmZ6KDP9HB20gl4UIIOqhBMNUwidAwYYMEDCZ/DBE6Ug0GEwqZ7J5ck2aDBAzoCAgwQIxAgi8fEKDJDJMCCtkZxoKagQ4M0IiCNBmhGhECinVETVSLWHdGhn2R0EyOvI1hVd3VsKEkrnHD8EEiupOj6Nh0ilRW+CBIp0iu0EfGthJhhGdgi9IMnOSVk4wjw6BGdgi4DBGHDCLsGCLsGCDDIYwi0IQchFIjssbJLqSBpIN01BFwGECVFDpIjrzhFzNgiBpDmBlzRBBisIGEQg5CuRRyNycEIMt7fggQukMi0eqIipE889pDYoJFUQ0lfYhwgguCKiEEHF0f0L7aBB1dWzM5PmzjtAgwg7vMlQaR0JtHhpJNoNxsY3bZOGwS4a2XjvDBMnZOIcOwkXD1ww9DSVA20cdpIOgRoDwg0QtITFIJXr0iJQ79RMCHBl2bNeENQlxhQ1YaULXtHH1jwfDsVFRhj5L/X7a+t1rhhK6KHaTX+GNkxw0Fns9msnSbSIY7C3tS7D0U4ahA1/qXAMIJY0XAYeC0iOPBBpAg+wTDEExCBPQW2l2bBueFOBzZnhTgmdBnBLpPTUmQ///f96bp3ZY9jimN/D4YaWGEG2Kigeo8fxDkcJR0NrLieglbSeTj7DDCwbzoakM/BhsMMMGHFbaXsnZd0XAaJ3cIuGEXYeEaAwicBzItOkjM6aas3kfB6//2yf/XMG6SqEFtNBFxNvrdWwgjmG3aaae5M+330nv3wl8Q8ODFNjvuXEpvouIHBFwwRoYeTwHsV+qodXqGm0tQ0/ZCUshC6wyLANKRaNOL9gwwYILjtBJhhoJg2DQhtNIaYMNBYfDBhDbUkOqczdbZvzZv5x0NGdT0PQQRhEebo0LEEXDs/v59ZQkmvZUAiP6QdQ77e1+/J0/iGGRzexBjiIiImaEI8zjn89RTlYbChoEisPqVQEUZTkGCYQZrCp2ThuDEECBhwg0KBipCaWmQinYq7bQXEJUIT03SEU++qoqGg7SwgdCp4knoREjnX+R2l1tf/ginddggtTngi4xERERERERFIREREREOIiIiIiII3HEFDYIzZzP6QMEGIQYMKGIJQQNhkcYJoPDFAgbEJJiEG0ohBtJtKKwl/67BhLXYZf0sINhmNeEEEEIiIiIiIiIiIiIiIiIMEIMsgwKfCzhF8QjOIIjtO4YbDBkckww4ZHJOgwbBkcoiIiIiIiIiIiIiIiIiP/8rhSj///////wAQAQCmVuZHN0cmVhbQplbmRvYmoKOCAwIG9iagoxMTUyMwplbmRvYmoKeHJlZgowIDkgCjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAxNiAwMDAwMCBuIAowMDAwMDAwMDY4IDAwMDAwIG4gCjAwMDAwMDAyMjkgMDAwMDAgbiAKMDAwMDAwMDI5MyAwMDAwMCBuIAowMDAwMDAwNDY5IDAwMDAwIG4gCjAwMDAwMDA1ODggMDAwMDAgbiAKMDAwMDAwMDYwNiAwMDAwMCBuIAowMDAwMDEyMzcyIDAwMDAwIG4gCnRyYWlsZXIKPDwKL1NpemUgOQovUm9vdCAxIDAgUiAKL0luZm8gMiAwIFIgCi9JRFs8NkI4QjQ1NjczMjdCMjNDNjY0M0M5ODY5NjYzMzQ4NzM+PDZCOEI0NTY3MzI3QjIzQzY2NDNDOTg2OTY2MzM0ODczPl0KPj4Kc3RhcnR4cmVmCjEyMzkzCiUlRU9GCg0KLS1NWVBzbWd0T2JLUVVibGFxNFFDZTk2Y2QNCkNvbnRlbnQtVHlwZTogdGV4dC9wbGFpbjsgY2hhcnNldD1VVEYtOA0KQ29udGVudC1EaXNwb3NpdGlvbjogZm9ybS1kYXRhOyBuYW1lPSJUbyINCg0KKzE2MTM3MDIyMzY0DQotLU1ZUHNtZ3RPYktRVWJsYXE0UUNlOTZjZA0KQ29udGVudC1UeXBlOiB0ZXh0L3BsYWluOyBjaGFyc2V0PVVURi04DQpDb250ZW50LURpc3Bvc2l0aW9uOiBmb3JtLWRhdGE7IG5hbWU9IkFjY291bnRTaWQiDQoNCkFDZDI3MDQzNDRlODM3YWFjMTI0YThkYmY1MWVlZWE0ODUNCi0tTVlQc21ndE9iS1FVYmxhcTRRQ2U5NmNkDQpDb250ZW50LVR5cGU6IHRleHQvcGxhaW47IGNoYXJzZXQ9VVRGLTgNCkNvbnRlbnQtRGlzcG9zaXRpb246IGZvcm0tZGF0YTsgbmFtZT0iRmF4U3RhdHVzIg0KDQpyZWNlaXZlZA0KLS1NWVBzbWd0T2JLUVVibGFxNFFDZTk2Y2QNCkNvbnRlbnQtVHlwZTogdGV4dC9wbGFpbjsgY2hhcnNldD1VVEYtOA0KQ29udGVudC1EaXNwb3NpdGlvbjogZm9ybS1kYXRhOyBuYW1lPSJSZW1vdGVTdGF0aW9uSWQiDQoNCg0KLS1NWVBzbWd0T2JLUVVibGFxNFFDZTk2Y2QNCkNvbnRlbnQtVHlwZTogdGV4dC9wbGFpbjsgY2hhcnNldD1VVEYtOA0KQ29udGVudC1EaXNwb3NpdGlvbjogZm9ybS1kYXRhOyBuYW1lPSJGcm9tIg0KDQorMTYxMzIyODc0MzANCi0tTVlQc21ndE9iS1FVYmxhcTRRQ2U5NmNkDQpDb250ZW50LVR5cGU6IHRleHQvcGxhaW47IGNoYXJzZXQ9VVRGLTgNCkNvbnRlbnQtRGlzcG9zaXRpb246IGZvcm0tZGF0YTsgbmFtZT0iQXBpVmVyc2lvbiINCg0KdjENCi0tTVlQc21ndE9iS1FVYmxhcTRRQ2U5NmNkDQpDb250ZW50LVR5cGU6IHRleHQvcGxhaW47IGNoYXJzZXQ9VVRGLTgNCkNvbnRlbnQtRGlzcG9zaXRpb246IGZvcm0tZGF0YTsgbmFtZT0iU3RhdHVzIg0KDQpyZWNlaXZlZA0KLS1NWVBzbWd0T2JLUVVibGFxNFFDZTk2Y2QtLQ=="
        let data = Data(base64Encoded: base64EncodedContent)!

        XCTAssertNoThrow(try FormDataDecoder().decode(TwilioFaxResponse.self, from: data, boundary: "MYPsmgtObKQUblaq4QCe96cd"))
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
