import Foundation
import XCTest
@testable import Multipart

class ParserTests: XCTestCase {
    static var allTests = [
        ("testInit", testInit),
        ("testPreamble", testPreamble),
        ("testPreambleWithFauxBoundaries", testPreambleWithFauxBoundaries),
        ("testParts", testParts),
        ("testHeaders", testHeaders),
        ("testEpilogue", testEpilogue),
        ("testFormData", testFormData),
    ]

    func testInit() throws {
        let parser = try Parser(boundary: "foo")
        XCTAssertEqual(parser.boundary, "foo".makeBytes())
    }
    
    func testPreamble() throws {
        let parser = try Parser(boundary: "foo")
        
        var preamble = ""
        preamble += "This is the preamble.  It is to be ignored, though it\n"
        preamble += "is a handy place for composition agents to include an\n"
        preamble += "explanatory note to non-MIME conformant readers.\n"
        preamble += "\n"
        
        var message = ""
        message += preamble
        message += "--foo--\n"
        
        let preambleExpectation = expectation(description: "preamble was parsed")
        
        parser.onPreamble = { parsedPreamble in
            XCTAssertEqual(parsedPreamble.makeString(), preamble)
            preambleExpectation.fulfill()
        }
        
        try parser.parse(message.makeBytes())
        
        waitForExpectations(timeout: 0, handler: nil)
    }
    
    func testPreambleWithFauxBoundaries() throws {
        let parser = try Parser(boundary: "foo")
        
        var preamble = ""
        preamble += "This is the preamble.  It is to be ignored, though it\n"
        preamble += "is a handy --fooxo\n place for --bar\n composition agents to include an\n"
        preamble += "explanatory note to non-MIME conformant readers.\n"
        preamble += "\n"
        
        var message = ""
        message += preamble
        message += "--foo--\r\n"
        
        let preambleExpectation = expectation(description: "preamble was parsed")
        
        parser.onPreamble = { parsedPreamble in
            XCTAssertEqual(parsedPreamble.makeString(), preamble)
            preambleExpectation.fulfill()
        }
        
        try parser.parse(message.makeBytes())
        
        waitForExpectations(timeout: 0, handler: nil)
    }
    
    func testParts() throws {
        let parser = try Parser(boundary: "foo")
        
        var preamble = ""
        preamble += "This is the preamble.  It is to be ignored, though it\n"
        preamble += "is a handy place for composition agents to include an\n"
        preamble += "explanatory note to non-MIME conformant readers.\n"
        preamble += "\n"
        
        let part1 = "testfoobar"
        
        var message = ""
        message += preamble
        message += "--foo\r\n"
        message += "\r\n"
        message += part1
        message += "--foo--\r\n"
        
        let partExpectation = expectation(description: "part was parsed")
        
        parser.onPart = { part in
            XCTAssertEqual(part.body.makeString(), part1)
            partExpectation.fulfill()
        }
        
        try parser.parse(message.makeBytes())
        
        waitForExpectations(timeout: 0, handler: nil)
    }
    
    func testHeaders() throws {
        let parser = try Parser(boundary: "foo")
        
        let part1 = "testfoobar"
        
        var message = ""
        message += "preamble"
        message += "--foo\r\n"
        message += "key:  value\r\n"
        message += "foo:bar\r\n"
        message += "\r\n"
        message += part1
        message += "--foo--\r\n"
        
        let partExpectation = expectation(description: "part was parsed")
        
        parser.onPart = { part in
            XCTAssertEqual(part.body.makeString(), part1)
            XCTAssertEqual(part.headers.count, 2)
            XCTAssertEqual(part.headers["key"], "value")
            XCTAssertEqual(part.headers["foo"], "bar")
            partExpectation.fulfill()
        }
        
        try parser.parse(message.makeBytes())
        
        waitForExpectations(timeout: 0, handler: nil)
    }
    
    func testEpilogue() throws {
        let parser = try Parser(boundary: "foo")
        
        let epilogue = "epliogue"
        
        var message = ""
        message += "preamble"
        message += "--foo\r\n"
        message += "\r\n"
        message += "part"
        message += "--foo--\r\n"
        message += epilogue
        
        let epilogueExpectation = expectation(description: "epilogue was parsed")
        
        parser.onEpilogue = { e in
            XCTAssertEqual(e.makeString(), epilogue)
            epilogueExpectation.fulfill()
        }
        
        try parser.parse(message.makeBytes())
        
        // must call done since epilogue can go on forever
        try parser.finish()
        
        waitForExpectations(timeout: 0, handler: nil)
    }
    
    func testFormData() throws {
        let parser = try Parser(boundary: "---------------------------9051914041544843365972754266")
        
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
        
        var parts: [Part] = []
        
        parser.onPart = { part in
            parts.append(part)
        }
        
        try parser.parse(message)
        
        XCTAssertEqual(parts.count, 3)
    }
	
	func testExtractBoundary() throws {
		let contentTypeValue = "multipart/form-data; boundary=asdf"
		
		XCTAssertEqual(try Parser.extractBoundary(contentType: contentTypeValue), "asdf".makeBytes())
	}
	
	/// Quotes around boundary is allowed in the HTTP spec, see https://tools.ietf.org/html/rfc7231#section-3.1.1.1
	func testExtractBoundaryWithQuotes() throws {
		let contentTypeValue = "multipart/form-data; boundary=\"asdf\""
		
		XCTAssertEqual(try Parser.extractBoundary(contentType: contentTypeValue), "asdf".makeBytes())
	}
}
