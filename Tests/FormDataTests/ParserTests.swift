import Foundation
import XCTest
@testable import FormData

class ParserTests: XCTestCase {
    static var allTests = [
        ("testInit", testInit),
        ("testFormData", testFormData),
    ]

    func testInit() throws {
        let parser = try Parser(boundary: "foo")
        XCTAssertEqual(parser.boundary, "foo".bytes)
    }
    
    func testFormData() throws {
        let parser = try Parser(boundary: "---------------------------9051914041544843365972754266")
        
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
        
        try parser.parse(message)
        
        XCTAssertEqual(fields.count, 3)
        
        XCTAssertNotNil(fields["text"])
        XCTAssertNotNil(fields["file1"])
        XCTAssertNotNil(fields["file2"])
        
        XCTAssertEqual(fields["text"]?.filename, nil)
        XCTAssertEqual(fields["file1"]?.filename, "a.txt")
        XCTAssertEqual(fields["file2"]?.filename, "a.html")
    }
}
