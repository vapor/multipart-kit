import Foundation
import XCTest
@testable import Multipart
import Core

class SerializerTests: XCTestCase {
    static var allTests = [
        ("testInit", testInit),
        ("testBasic", testBasic),
    ]
    
    func testInit() throws {
        let serializer = try Serializer(boundary: "foo")
        XCTAssertEqual(serializer.boundary, "foo".bytes)
    }
    
    public func testBasic() throws {
        let part1 = Part(headers: [
            "Content-Type": "text/plain; charset=us-ascii",
            "X-Test": "42"
        ], body: "Systems should choose the 'best' type based on the local environment and references, in some cases even through user interaction.".bytes)
        
        let part2 = Part(headers: [:], body: "Test123".bytes)
        
        let serializer = try Serializer(boundary: "boundary42")
        
        var serialized: Bytes = []
        
        serializer.onSerialize = { bytes in
            serialized += bytes
        }
        
        try serializer.serialize(part1)
        try serializer.serialize(part2)
        try serializer.finish()
        
        var expected = ""
        
        expected += "--boundary42\n"
        expected += "Content-Type: text/plain; charset=us-ascii\n"
        expected += "X-Test: 42\n"
        expected += "\n"
        expected += "Systems should choose the 'best' type based on the local environment and references, in some cases even through user interaction.\n"
        expected += "--boundary42\n"
        expected += "\n"
        expected += "Test123\n"
        expected += "--boundary42--\n"
        
        XCTAssertEqual(serialized.string, expected)
    }
}
