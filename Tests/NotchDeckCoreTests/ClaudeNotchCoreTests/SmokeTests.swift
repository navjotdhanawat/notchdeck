import XCTest
@testable import NotchDeckCore

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(ClaudeNotchCore.version, "0.1.0")
    }
}
