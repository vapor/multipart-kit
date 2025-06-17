import HTTPTypes
import MultipartKit
import Testing

@Suite("Content-Disposition Tests")
struct ContentDispositionTests {
    @Test("Parse Content-Disposition")
    func testContentDispositionParsing() throws {
        let part1 = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name=\"fieldName\""],
            body: []
        )

        let disposition1 = try part1.contentDisposition
        #expect(disposition1.name == "fieldName")
        #expect(disposition1.filename == nil)
        #expect(disposition1.additionalParameters.isEmpty == true)

        let part2 = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name=\"file\"; filename=\"example.txt\""],
            body: []
        )

        let disposition2 = try part2.contentDisposition
        #expect(disposition2.name == "file")
        #expect(disposition2.filename == "example.txt")
        #expect(disposition2.additionalParameters.isEmpty == true)

        let part3 = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name=\"user\"; size=1024; custom=\"value\""],
            body: []
        )

        let disposition3 = try part3.contentDisposition
        #expect(disposition3.name == "user")
        #expect(disposition3.filename == nil)
        #expect(disposition3.additionalParameters["size"] == "1024")
        #expect(disposition3.additionalParameters["custom"] == "value")
    }

    @Test("Correct Content-Disposition Errors")
    func testContentDispositionErrors() {
        let part1 = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "file; name=\"file\""],
            body: []
        )

        #expect(throws: ContentDisposition.Error.invalidDispositionType("file")) {
            try part1.contentDisposition
        }

        let part2 = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; filename=\"example.txt\""],
            body: []
        )

        #expect(throws: ContentDisposition.Error.missingField("name")) {
            try part2.contentDisposition
        }

        let part3 = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name=\"file\"; name=\"duplicate\""],
            body: []
        )

        #expect(throws: ContentDisposition.Error.duplicateField("name")) {
            try part3.contentDisposition
        }

        let part4 = MultipartPart<[UInt8]>(
            headerFields: [:],
            body: []
        )

        #expect(throws: ContentDisposition.Error.missingContentDisposition) {
            try part4.contentDisposition
        }
    }

    @Test("Parse Quoted Content-Disposition Field")
    func testQuotedParameterParsing() throws {
        let part = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name=\"user data\"; filename=\"file with spaces.txt\""],
            body: []
        )

        let disposition = try part.contentDisposition
        #expect(disposition.name == "user data")
        #expect(disposition.filename == "file with spaces.txt")
    }
}
