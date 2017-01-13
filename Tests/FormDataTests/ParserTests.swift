import Foundation
import XCTest
@testable import FormData
import Multipart

class ParserTests: XCTestCase {
    static var allTests = [
        ("testFormData", testFormData),
        ("testWebkit", testWebkit),
    ]

    func testFormData() throws {
        let multipart = try Multipart.Parser(boundary: "---------------------------9051914041544843365972754266")
        let parser = FormData.Parser(multipart: multipart)
        
        var message = ""
        
        message += "-----------------------------9051914041544843365972754266\n"
        message += "Content-Disposition: form-data; name=\"text\"\n"
        message += "\n"
        message += "text default\n"
        message += "-----------------------------9051914041544843365972754266\n"
        message += "Content-Disposition: form-data; name=\"file1\"; filename=\"a.txt\"\n"
        message += "Content-Type: text/plain\n"
        message += "\n"
        message += "Content of a.txt.\n"
        message += "\n"
        message += "-----------------------------9051914041544843365972754266\n"
        message += "Content-Disposition: form-data; name=\"file2\"; filename=\"a.html\"\n"
        message += "Content-Type: text/html\n"
        message += "\n"
        message += "<!DOCTYPE html><title>Content of a.html.</title>\n"
        message += "\n"
        message += "-----------------------------9051914041544843365972754266--\n"
        
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
}
