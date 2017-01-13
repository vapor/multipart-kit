import Foundation
import XCTest
@testable import FormData
import Multipart
import Core
import HTTP

class SerializerTests: XCTestCase {
    static var allTests = [
        ("testInit", testInit),
        ("testBasic", testBasic),
    ]

    
    func testInit() throws {
        let serializer = try FormData.Serializer(boundary: "foo")
        XCTAssertEqual(serializer.boundary, "foo".bytes)
    }
    
    public func testBasic() throws {
        let part1 = Part(headers: [
            "Content-Type": "text/plain; charset=us-ascii",
        ], body: "Systems should choose the 'best' type based on the local environment and references, in some cases even through user interaction.".bytes)
        
        let part2 = Multipart.Part(headers: [:], body: "Test123".bytes)
        
        let field1 = Field(name: "title", filename: nil, part: part1)
        let field2 = Field(name: "image", filename: "image.jpg", part: part2)
        
        let serializer = try FormData.Serializer(boundary: "boundary42")
        
        var serialized: Bytes = []
        
        serializer.multipartSerializer.onSerialize = { bytes in
            serialized += bytes
        }
        
        try serializer.serialize(field1)
        try serializer.serialize(field2)
        try serializer.multipartSerializer.finish()
        
        var expected = ""
        
        expected += "--boundary42\n"
        expected += "Content-Disposition: form-data; name=\"title\"\n"
        expected += "Content-Type: text/plain; charset=us-ascii\n"
        expected += "\n"
        expected += "Systems should choose the 'best' type based on the local environment and references, in some cases even through user interaction.\n"
        expected += "--boundary42\n"
        expected += "Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\n"
        expected += "\n"
        expected += "Test123\n"
        expected += "--boundary42--\n"
        
        XCTAssertEqual(serialized.string, expected)
    }
}
