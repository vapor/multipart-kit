import Foundation
import XCTest
@testable import Multipart

class ParserTests: XCTestCase {
    static var allTests = [
        ("testInit", testInit),
        ("testPreamble", testPreamble),
        ("testPreambleWithFauxBoundaries", testPreambleWithFauxBoundaries),
    ]

    func testInit() {
        let parser = Parser(boundary: "foo")
        XCTAssertEqual(parser.boundary, "foo".bytes)
    }
    
    func testPreamble() {
        let parser = Parser(boundary: "foo")
        
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
            XCTAssertEqual(parsedPreamble.string, preamble)
            preambleExpectation.fulfill()
        }
        
        parser.parse(message.bytes)
        
        waitForExpectations(timeout: 0, handler: nil)
    }
    
    func testPreambleWithFauxBoundaries() {
        let parser = Parser(boundary: "foo")
        
        var preamble = ""
        preamble += "This is the preamble.  It is to be ignored, though it\n"
        preamble += "is a handy --fooxo\n place for --bar\n composition agents to include an\n"
        preamble += "explanatory note to non-MIME conformant readers.\n"
        preamble += "\n"
        
        var message = ""
        message += preamble
        message += "--foo--\n"
        
        let preambleExpectation = expectation(description: "preamble was parsed")
        
        parser.onPreamble = { parsedPreamble in
            XCTAssertEqual(parsedPreamble.string, preamble)
            preambleExpectation.fulfill()
        }
        
        parser.parse(message.bytes)
        
        waitForExpectations(timeout: 0, handler: nil)
    }
    
    func testParts() {
        let parser = Parser(boundary: "foo")
        
        var preamble = ""
        preamble += "This is the preamble.  It is to be ignored, though it\n"
        preamble += "is a handy place for composition agents to include an\n"
        preamble += "explanatory note to non-MIME conformant readers.\n"
        preamble += "\n"
        
        let part1 = "testfoobar"
        
        var message = ""
        message += preamble
        message += "--foo\n"
        message += part1
        message += "--foo--\n"
        
        let partExpectation = expectation(description: "part was parsed")
        
        parser.onPart = { part in
            XCTAssertEqual(part.body.string, part1)
            partExpectation.fulfill()
        }
        
        parser.parse(message.bytes)
        
        waitForExpectations(timeout: 0, handler: nil)
    }
}
