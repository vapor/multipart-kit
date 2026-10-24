#if canImport(Testing)
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

        let disposition1 = try #require(try part1.contentDisposition)
        #expect(disposition1.name == "fieldName")
        #expect(disposition1.filename == nil)
        #expect(disposition1.additionalParameters.isEmpty == true)

        let part2 = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name=\"file\"; filename=\"example.txt\""],
            body: []
        )

        let disposition2 = try #require(try part2.contentDisposition)
        #expect(disposition2.name == "file")
        #expect(disposition2.filename == "example.txt")
        #expect(disposition2.additionalParameters.isEmpty == true)

        let part3 = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name=\"user\"; size=1024; custom=\"value\""],
            body: []
        )

        let disposition3 = try #require(try part3.contentDisposition)
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

        // let part2 = MultipartPart<[UInt8]>(
        //     headerFields: [.contentDisposition: "form-data; filename=\"example.txt\""],
        //     body: []
        // )

        // #expect(throws: ContentDisposition.Error.missingField("name")) {
        //     try part2.contentDisposition
        // }

        let part3 = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name=\"file\"; name=\"duplicate\""],
            body: []
        )

        #expect(throws: ContentDisposition.Error.duplicateField("name")) {
            try part3.contentDisposition
        }
    }

    @Test("Parse Quoted Content-Disposition Field")
    func testQuotedParameterParsing() throws {
        let part = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name=\"user data\"; filename=\"file with spaces.txt\""],
            body: []
        )

        let disposition = try #require(try part.contentDisposition)
        #expect(disposition.name == "user data")
        #expect(disposition.filename == "file with spaces.txt")
    }

    @Test("Parse Content-Disposition with separators inside quotes and any letter case")
    func testContentDispositionQuotedSeparators() throws {
        let disposition = try ContentDisposition(from: #"Form-Data; Name="report"; FILENAME="report; final.pdf""#)
        #expect(disposition.dispositionType == .formData)
        #expect(disposition.name == "report")
        #expect(disposition.filename == "report; final.pdf")

        // Single quotes aren't quoting characters in HTTP, so they stay part of the value.
        let apostrophes = try ContentDisposition(from: #"form-data; name="f"; filename="'draft'.txt""#)
        #expect(apostrophes.filename == "'draft'.txt")
    }

    @Test("Parse Content-Disposition with escaped quotes and line breaks")
    func testContentDispositionEscapes() throws {
        // What `curl --form-escape` sends for a file named `a"b\c%22.txt`: its `%22` is literal.
        let backslashes = try ContentDisposition(from: #"form-data; filename="a\"b\\c%22.txt"; name="file""#)
        #expect(backslashes.filename == #"a"b\c%22.txt"#)
        #expect(backslashes.name == "file")

        // What browsers and curl send for a file named `a"b\c.txt`: only `"`, CR and LF are percent-encoded.
        let percents = try ContentDisposition(from: #"form-data; name="a%22b%0D%0Ac"; filename="a%22b\c.txt""#)
        #expect(percents.name == "a\"b\r\nc")
        #expect(percents.filename == #"a"b\c.txt"#)

        let windowsPath = try ContentDisposition(from: #"form-data; name="file"; filename="C:\Users\a.txt""#)
        #expect(windowsPath.filename == #"C:\Users\a.txt"#)
    }

    @Test("Parse Content-Disposition with unescaped quotes")
    func testContentDispositionUnescapedQuotes() throws {
        let quotedFilename = try ContentDisposition(from: #"form-data; filename="a"b.txt"; name="file""#)
        #expect(quotedFilename.filename == #"a"b.txt"#)
        #expect(quotedFilename.name == "file")

        let quotedName = try ContentDisposition(from: #"form-data; name="a"b"; filename="x.txt""#)
        #expect(quotedName.name == #"a"b"#)
        #expect(quotedName.filename == "x.txt")

        let token = try ContentDisposition(from: #"form-data; name=a"b; filename="x.txt""#)
        #expect(token.name == #"a"b"#)
        #expect(token.filename == "x.txt")
    }

    @Test("Parse Content-Disposition parameter names in any letter case")
    func testContentDispositionParameterCase() throws {
        let disposition = try ContentDisposition(from: #"form-data; name="a"; FileName*=UTF-8''x.txt; Size=1"#)
        #expect(disposition.additionalParameters == ["filename*": "UTF-8''x.txt", "size": "1"])
    }

    @Test("Edge case Content-Disposition headers")
    func testContentDispositionEdgeCases() {
        let empty = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: ""],
            body: []
        )

        #expect(throws: ContentDisposition.Error.missingContentDisposition) {
            try empty.contentDisposition
        }

        let semis = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: ";;;"],
            body: []
        )

        #expect(throws: ContentDisposition.Error.missingContentDisposition) {
            try semis.contentDisposition
        }

        // let formOnly = MultipartPart<[UInt8]>(
        //     headerFields: [.contentDisposition: "form-data"],
        //     body: []
        // )

        // #expect(throws: ContentDisposition.Error.missingField("name")) {
        //     try formOnly.contentDisposition
        // }

        let paramOnly = MultipartPart<[UInt8]>(
            headerFields: [.contentDisposition: "form-data; name"],
            body: []
        )

        #expect(throws: ContentDisposition.Error.invalidParameterFormat("name")) {
            try paramOnly.contentDisposition
        }
    }
}

#endif  // canImport(Testing)
