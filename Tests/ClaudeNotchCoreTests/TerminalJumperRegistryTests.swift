import XCTest
@testable import ClaudeNotchCore

private final class FakeJumper: TerminalJumping, @unchecked Sendable {
    let adapterID: String
    let result: JumpResult
    private(set) var called = false
    init(_ adapterID: String, _ result: JumpResult) { self.adapterID = adapterID; self.result = result }
    func jump(to identity: TerminalIdentity) async -> JumpResult { called = true; return result }
}

final class TerminalJumperRegistryTests: XCTestCase {
    private func identity(_ adapterID: String) -> TerminalIdentity {
        TerminalIdentity(adapterID: adapterID, handle: "H")
    }

    func testAdapterJumpedShortCircuits() async {
        let fallback = FakeJumper("generic", .fellBack)
        let reg = TerminalJumperRegistry(adapters: [FakeJumper("iterm2", .jumped)], fallback: fallback)
        let r = await reg.jump(to: identity("iterm2"))
        XCTAssertEqual(r, .jumped)
        XCTAssertFalse(fallback.called)
    }

    func testAdapterFailedFallsBackToFallback() async {
        let fallback = FakeJumper("generic", .fellBack)
        let reg = TerminalJumperRegistry(adapters: [FakeJumper("iterm2", .failed("x"))], fallback: fallback)
        let r = await reg.jump(to: identity("iterm2"))
        XCTAssertEqual(r, .fellBack)
        XCTAssertTrue(fallback.called)
    }

    func testAdapterFellBackDoesNotCallFallback() async {
        let fallback = FakeJumper("generic", .jumped)
        let reg = TerminalJumperRegistry(adapters: [FakeJumper("iterm2", .fellBack)], fallback: fallback)
        let r = await reg.jump(to: identity("iterm2"))
        XCTAssertEqual(r, .fellBack)
        XCTAssertFalse(fallback.called)
    }

    func testUnknownAdapterGoesStraightToFallback() async {
        let fallback = FakeJumper("generic", .fellBack)
        let reg = TerminalJumperRegistry(adapters: [FakeJumper("iterm2", .jumped)], fallback: fallback)
        let r = await reg.jump(to: identity("ghostty"))
        XCTAssertEqual(r, .fellBack)
        XCTAssertTrue(fallback.called)
    }
}
