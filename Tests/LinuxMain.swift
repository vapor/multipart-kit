import XCTest

@testable import FormDataTests
@testable import MultipartTests

XCTMain([
    testCase(ParserTests.allTests),
    testCase(SerializerTests.allTests),
    testCase(ParserTests.allTests),
    testCase(SerializerTests.allTests),
])

