import XCTest
@testable import NotchDeckCore

final class RememberedDecisionsTests: XCTestCase {
    func testRememberThenAllowedForSameSessionAndTool() {
        let r = RememberedDecisions()
        XCTAssertFalse(r.isAllowed(sessionKey: "S", tool: "Bash"))
        r.remember(sessionKey: "S", tool: "Bash")
        XCTAssertTrue(r.isAllowed(sessionKey: "S", tool: "Bash"))
        XCTAssertFalse(r.isAllowed(sessionKey: "S", tool: "Edit"))   // scoped per tool
        XCTAssertFalse(r.isAllowed(sessionKey: "T", tool: "Bash"))   // scoped per session
    }

    func testClearSession() {
        let r = RememberedDecisions()
        r.remember(sessionKey: "S", tool: "Bash")
        r.clear(sessionKey: "S")
        XCTAssertFalse(r.isAllowed(sessionKey: "S", tool: "Bash"))
    }

    func testClearAll() {
        let r = RememberedDecisions()
        r.remember(sessionKey: "S", tool: "Bash")
        r.remember(sessionKey: "T", tool: "Edit")
        r.clearAll()
        XCTAssertFalse(r.isAllowed(sessionKey: "S", tool: "Bash"))
        XCTAssertFalse(r.isAllowed(sessionKey: "T", tool: "Edit"))
    }
}
