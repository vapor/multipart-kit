import XCTest

@testable import FormDataTests
@testable import MultipartTests

XCTMain([
    testCase(FormDataTests.ParserTests.allTests),
    testCase(FormDataTests.SerializerTests.allTests),
    testCase(MultipartTests.ParserTests.allTests),
    testCase(MultipartTests.SerializerTests.allTests),
])

