import Foundation
import XCTest
@testable import FormData
import Multipart
import Core
import HTTP

class SerializerTests: XCTestCase {
    static var allTests = [
        ("testBasic", testBasic),
    ]
    
    public func testBasic() throws {
        let part1 = Part(headers: [
            "Content-Type": "text/plain; charset=us-ascii",
        ], body: "Systems should choose the 'best' type based on the local environment and references, in some cases even through user interaction.".bytes)
        
        let part2 = Multipart.Part(headers: [:], body: "Test123".bytes)
        
        let field1 = Field(name: "title", filename: nil, part: part1)
        let field2 = Field(name: "image", filename: "image.jpg", part: part2)
        
        let multipart = try Multipart.Serializer(boundary: "boundary42")
        let serializer = FormData.Serializer(multipart: multipart)
        
        var serialized: Bytes = []
        
        serializer.multipart.onSerialize = { bytes in
            serialized += bytes
        }
        
        try serializer.serialize(field1)
        try serializer.serialize(field2)
        try serializer.multipart.finish()
        
        var expected = ""
        
        expected += "--boundary42\r\n"
        #if os(Linux)
            expected += "Content-Type: text/plain; charset=us-ascii\r\n"
            expected += "Content-Disposition: form-data; name=\"title\"\r\n"
        #else
            expected += "Content-Disposition: form-data; name=\"title\"\r\n"
            expected += "Content-Type: text/plain; charset=us-ascii\r\n"
        #endif
        expected += "\r\n"
        expected += "Systems should choose the 'best' type based on the local environment and references, in some cases even through user interaction.\r\n"
        expected += "--boundary42\r\n"
        expected += "Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n"
        expected += "\r\n"
        expected += "Test123\r\n"
        expected += "--boundary42--\r\n"
        
        XCTAssertEqual(serialized.string, expected)
    }
}
