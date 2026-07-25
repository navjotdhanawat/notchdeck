import XCTest
@testable import ClaudeNotchCore

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(ClaudeNotchCore.version, "0.1.0")
    }
}
