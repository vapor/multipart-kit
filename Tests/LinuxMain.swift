#if os(Linux)

import XCTest
@testable import MultipartTests
XCTMain([
    testCase(MultipartTests.allTests),
    testCase(MultipartDateTests.allTests),
])

#endif
