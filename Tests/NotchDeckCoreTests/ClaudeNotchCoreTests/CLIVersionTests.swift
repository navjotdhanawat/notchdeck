import XCTest
@testable import NotchDeckCore

final class CLIVersionTests: XCTestCase {
    func testParsesClaudeStyle() {
        XCTAssertEqual(CLIVersion.parse("2.1.217 (Claude Code)")!.0, 2)
        XCTAssertEqual(CLIVersion.parse("2.1.217 (Claude Code)")!.2, 217)
    }
    func testParsesPrefixedStyle() {
        // A CLI that prints a name before the semver (e.g. "codex-cli 0.20.3").
        XCTAssertEqual(CLIVersion.parse("codex-cli 0.20.3")!.1, 20)
        XCTAssertEqual(CLIVersion.parse("codex-cli 0.20.3")!.2, 3)
    }
    func testMeetsMinimum() {
        XCTAssertTrue(CLIVersion.meetsMinimum("2.1.217 (Claude Code)", (2, 1, 200)))
        XCTAssertFalse(CLIVersion.meetsMinimum("2.1.199", (2, 1, 200)))
        XCTAssertTrue(CLIVersion.meetsMinimum("2.2.0", (2, 1, 200)))
        XCTAssertFalse(CLIVersion.meetsMinimum("garbage", (2, 1, 200)))
    }
}
