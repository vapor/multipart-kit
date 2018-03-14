import Foundation
import XCTest
import Bits
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
        ("testExtractBoundary", testExtractBoundary),
        ("testExtractBoundaryWithQuotes", testExtractBoundaryWithQuotes),
        ("testPerformance_100_KB", testPerformance_100_KB),
        ("testPerformance_200_KB", testPerformance_200_KB),
        ("testPerformance_400_KB", testPerformance_400_KB),
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
        
        let epilogue = "epilogue"
        
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

    func testPerformance_100_KB() {
        let (message, numberOfParts) = makeMessage(boundary: "frontier", targetSize: 100_000)
        measureMetrics(type(of: self).defaultMetrics, automaticallyStartMeasuring: false) {
            measureParser(boundary: "frontier", message: message, expectedNumberOfParts: numberOfParts)
        }
    }

    func testPerformance_200_KB() {
        let (message, numberOfParts) = makeMessage(boundary: "frontier", targetSize: 200_000)
        measureMetrics(type(of: self).defaultMetrics, automaticallyStartMeasuring: false) {
            measureParser(boundary: "frontier", message: message, expectedNumberOfParts: numberOfParts)
        }
    }

    func testPerformance_400_KB() {
        let (message, numberOfParts) = makeMessage(boundary: "frontier", targetSize: 400_000)
        measureMetrics(type(of: self).defaultMetrics, automaticallyStartMeasuring: false) {
            measureParser(boundary: "frontier", message: message, expectedNumberOfParts: numberOfParts)
        }
    }

    /// Helper method to measure the performance of the Multipart parser.
    /// You must call this from inside a
    /// `measureMetrics([.wallClockTime], automaticallyStartMeasuring: false)`
    /// block.
    ///
    /// - Parameter boundary: The multipart boundary.
    /// - Parameter message: The message that should be parsed. The message is
    ///   expected to have a preamble and an epilogue.
    /// - Parameter expectedNumberOfParts: The number of parts in the message.
    ///   We use this value to test that the parser works correctly.
    private func measureParser(boundary: String, message: Bytes, expectedNumberOfParts: Int) {
        do {
            let parser = try Parser(boundary: boundary)

            var actualCounts = (preambles: 0, parts: 0, epilogues: 0)
            parser.onPreamble = { _ in actualCounts.preambles += 1 }
            parser.onPart = { _ in actualCounts.parts += 1 }
            parser.onEpilogue = { _ in actualCounts.epilogues += 1 }

            startMeasuring()
            try parser.parse(message)
            try parser.finish()
            stopMeasuring()

            XCTAssertEqual(actualCounts.preambles, 1)
            XCTAssertEqual(actualCounts.parts, expectedNumberOfParts)
            XCTAssertEqual(actualCounts.epilogues, 1)
        } catch {
            XCTFail("Parse error: \(error)")
        }
    }

    // corelibs-XCTestLinux in Swift 4.0 expects performance metrics to be a
    // `[String]` instead of the documented `[XCTPerformanceMetric]`, and the
    // `XCTestCase.defaultPerformanceMetrics` API is a function, not a property.
    // The API has been updated for Swift 4.1, see https://bugs.swift.org/browse/SR-5643
    // and https://github.com/apple/swift-corelibs-xctest/pull/198.
    #if swift(>=4.1) || (swift(>=4.0) && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS)))
        private class var defaultMetrics: [XCTPerformanceMetric] {
            return defaultPerformanceMetrics
        }
    #else
        private class var defaultMetrics: [String] {
            return defaultPerformanceMetrics()
        }
    #endif
}

/// Helper function to generate a multipart message of a given size.
///
/// - Parameter boundary: The multipart boundary the message should use.
/// - Parameter targetSize: The desired size of the message in bytes.
///   The returned message may be slightly larger than this value.
/// - Returns: A generated multipart message and the number of parts the message
///   contains. The message will contain at least one part, even if the input
///   size is very small.
private func makeMessage(boundary: String, targetSize: Int) -> (message: Bytes, numberOfParts: Int) {
    func makePart(index: Int) -> Bytes {
        var part = ""
        part += "--\(boundary)\r\n"
        part += "Content-Type: text/plain\r\n"
        part += "X-Counter: \(index)\r\n"
        part += "\r\n"
        part += "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam id tortor et tellus bibendum suscipit."
        part += "\r\n"
        return part.makeBytes()
    }

    var message: Bytes = []
    message += "preamble".makeBytes()
    var counter = 0
    repeat {
        counter += 1
        message += makePart(index: counter)
    } while message.count <= targetSize
    message += "--\(boundary)--\r\n".makeBytes()
    message += "epilogue".makeBytes()
    return (message, counter)
}
