import Foundation
import XCTest
@testable import FormData
import Multipart

class ParserTests: XCTestCase {
    static var allTests = [
        ("testFormData", testFormData),
        ("testWebkit", testWebkit),
        ("testForm", testForm),
        ("testFormManyFields", testFormManyFields)
    ]

    func testFormData() throws {
        let multipart = try Multipart.Parser(boundary: "---------------------------9051914041544843365972754266")
        let parser = FormData.Parser(multipart: multipart)
        
        var message = ""
        
        message += "-----------------------------9051914041544843365972754266\r\n"
        message += "Content-Disposition: form-data; name=\"text\"\r\n"
        message += "\r\n"
        message += "text default\r\n"
        message += "-----------------------------9051914041544843365972754266\r\n"
        message += "Content-Disposition: form-data; name=\"file1\"; filename=\"a.txt\"\r\n"
        message += "Content-Type: text/plain\r\n"
        message += "\r\n"
        message += "Content of a.txt.\r\n"
        message += "\r\n"
        message += "-----------------------------9051914041544843365972754266\r\n"
        message += "Content-Disposition: form-data; name=\"file2\"; filename=\"a.html\"\r\n"
        message += "Content-Type: text/html\r\n"
        message += "\r\n"
        message += "<!DOCTYPE html><title>Content of a.html.</title>\r\n"
        message += "\r\n"
        message += "-----------------------------9051914041544843365972754266--\r\n"
        
        var fields: [String: Field] = [:]
        
        parser.onField = { field in
            fields[field.name] = field
        }
        
        try parser.multipart.parse(message)
        
        XCTAssertEqual(fields.count, 3)
        
        XCTAssertNotNil(fields["text"])
        XCTAssertNotNil(fields["file1"])
        XCTAssertNotNil(fields["file2"])
        
        XCTAssertEqual(fields["text"]?.filename, nil)
        XCTAssertEqual(fields["file1"]?.filename, "a.txt")
        XCTAssertEqual(fields["file2"]?.filename, "a.html")
    }
    
    func testWebkit() throws {
        var message = ""

        message += "------WebKitFormBoundaryezkRLRyEVe1aMUVZ\r\n"
        message += "Content-Disposition: form-data; name=\"file\"; filename=\"Screen Shot 2017-01-13 at 3.05.26 PM.png\"\r\n"
        message += "Content-Type: image/png\r\n"
        message += "\r\n"
        message += "PNG\n"
        message += "\n"
        message += "\n"
        message += "------WebKitFormBoundaryezkRLRyEVe1aMUVZ--\r\n"
        
        let multipart = try Multipart.Parser(boundary: "----WebKitFormBoundaryezkRLRyEVe1aMUVZ")
        let parser = FormData.Parser(multipart: multipart)
        
        var fields: [String: Field] = [:]
        
        parser.onField = { field in
            fields[field.name] = field
        }
        
        try parser.multipart.parse(message)
        
        XCTAssertEqual(fields["file"]?.filename, "Screen Shot 2017-01-13 at 3.05.26 PM.png")
    }
    
    func testForm() throws {
        var message = ""
        
        message += "--vapor\r\n"
        message += "Content-Disposition: form-data; name=\"name\"\r\n"
        message += "Content-Type: text\r\n"
        message += "\r\n"
        message += "hi\r\n"
        message += "--vapor--\r\n"
        
        let multipart = try Multipart.Parser(boundary: "vapor")
        let parser = FormData.Parser(multipart: multipart)
        
        var fields: [String: Field] = [:]
        
        parser.onField = { field in
            fields[field.name] = field
        }
        
        try parser.multipart.parse(message)
        
        XCTAssertEqual(fields["name"]?.part.body.makeString(), "hi")
    }

    func testFormManyFields() throws {
        var message = ""
        
        message += "------WebKitFormBoundaryMFxQS4UblUjPXRXM\r\n"
        message += "Content-Disposition: form-data; name=\"field1\"\r\n\r\n"
        message += "The Quick Brown Fox Jumps Over The Lazy Dog\r\n"
        message += "------WebKitFormBoundaryMFxQS4UblUjPXRXM\r\n"
        message += "Content-Disposition: form-data; name=\"field2\"\r\n\r\n"
        message += "The Quick Brown Fox Jumps Over The Lazy Dog\r\n"
        message += "------WebKitFormBoundaryMFxQS4UblUjPXRXM\r\n"
        message += "Content-Disposition: form-data; name=\"field3\"\r\n\r\n"
        message += "The Quick Brown Fox Jumps Over The Lazy Dog\r\n"
        message += "------WebKitFormBoundaryMFxQS4UblUjPXRXM\r\n"
        message += "Content-Disposition: form-data; name=\"field4\"\r\n\r\n"
        message += "The Quick Brown Fox Jumps Over The Lazy Dog\r\n"
        message += "------WebKitFormBoundaryMFxQS4UblUjPXRXM\r\n"
        message += "Content-Disposition: form-data; name=\"field5\"\r\n\r\n"
        message += "The Quick Brown Fox Jumps Over The Lazy Dog\r\n"
        message += "------WebKitFormBoundaryMFxQS4UblUjPXRXM\r\n"
        
        let multipart = try Multipart.Parser(boundary: "----WebKitFormBoundaryMFxQS4UblUjPXRXM")
        let parser = FormData.Parser(multipart: multipart)
        
        var fields: [String: Field] = [:]
        
        parser.onField = { field in
            fields[field.name] = field
        }
        
        try parser.multipart.parse(message)
        
        for i in 1...5 {
            XCTAssertEqual(fields["field\(i)"]?.part.body.makeString(), "The Quick Brown Fox Jumps Over The Lazy Dog", "Field 'field\(i)' was parsed incorrectly!")
        }
    }
}
