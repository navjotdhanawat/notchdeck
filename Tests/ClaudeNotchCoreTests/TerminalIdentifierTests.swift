import XCTest
@testable import ClaudeNotchCore

final class TerminalIdentifierTests: XCTestCase {
    private let reg = TerminalIdentifierRegistry.default

    func testITermResolvesToUUIDHandle() {
        let id = reg.resolve(HookEnv(values: ["ITERM_SESSION_ID": "w0t1p0:ABC-123",
                                              "TERM_PROGRAM": "iTerm.app"], pid: 7))
        XCTAssertEqual(id.adapterID, "iterm2")
        XCTAssertEqual(id.handle, "ABC-123")        // colon prefix stripped
        XCTAssertEqual(id.appName, "iTerm.app")
        XCTAssertEqual(id.pid, 7)
    }

    func testITermUUIDWithoutColonPassesThrough() {
        let id = ITerm2Identifier().identify(HookEnv(values: ["ITERM_SESSION_ID": "ABC-123"]))
        XCTAssertEqual(id?.handle, "ABC-123")
    }

    func testWezTermResolvesToPaneHandle() {
        let id = reg.resolve(HookEnv(values: ["WEZTERM_PANE": "42", "TERM_PROGRAM": "WezTerm"]))
        XCTAssertEqual(id.adapterID, "wezterm")
        XCTAssertEqual(id.handle, "42")
    }

    func testKittyResolvesToWindowHandle() {
        let id = reg.resolve(HookEnv(values: ["KITTY_WINDOW_ID": "3"]))
        XCTAssertEqual(id.adapterID, "kitty")
        XCTAssertEqual(id.handle, "3")
    }

    func testUnknownTerminalResolvesToGeneric() {
        let id = reg.resolve(HookEnv(values: ["TERM_PROGRAM": "Ghostty"]))
        XCTAssertEqual(id.adapterID, "generic")
        XCTAssertNil(id.handle)
        XCTAssertEqual(id.appName, "Ghostty")
    }

    func testResolveIsTotalWithEmptyEnv() {
        XCTAssertEqual(reg.resolve(HookEnv()).adapterID, "generic")
    }

    func testSpecificWinsOverGenericByPriority() {
        // iTerm env also carries TERM_PROGRAM (generic's key); specific must win.
        let id = reg.resolve(HookEnv(values: ["ITERM_SESSION_ID": "w0:X", "TERM_PROGRAM": "iTerm.app"]))
        XCTAssertEqual(id.adapterID, "iterm2")
    }

    func testAllEnvKeysIsDedupedUnion() {
        let keys = Set(reg.allEnvKeys)
        XCTAssertEqual(keys, ["ITERM_SESSION_ID", "TERM_PROGRAM", "WEZTERM_PANE", "KITTY_WINDOW_ID"])
    }

    func testKeyUsesHandleElseSessionID() {
        XCTAssertEqual(SessionKey.derive(identity: TerminalIdentity(adapterID: "iterm2", handle: "U-9"),
                                         sessionID: "s1"), "iterm2:U-9")
        XCTAssertEqual(SessionKey.derive(identity: TerminalIdentity(adapterID: "generic"),
                                         sessionID: "s1"), "s1")
        XCTAssertEqual(reg.key(for: HookEnv(values: ["ITERM_SESSION_ID": "w0:U-9"]), sessionID: "s1"), "iterm2:U-9")
        XCTAssertEqual(reg.key(for: HookEnv(values: ["TERM_PROGRAM": "Ghostty"]), sessionID: "s1"), "s1")
        // Same handle, different adapter → distinct keys (WezTerm pane 1 vs Kitty window 1 must not collide).
        XCTAssertEqual(SessionKey.derive(identity: TerminalIdentity(adapterID: "wezterm", handle: "1"), sessionID: "sA"), "wezterm:1")
        XCTAssertEqual(SessionKey.derive(identity: TerminalIdentity(adapterID: "kitty", handle: "1"), sessionID: "sB"), "kitty:1")
        XCTAssertNotEqual(SessionKey.derive(identity: TerminalIdentity(adapterID: "wezterm", handle: "1"), sessionID: "sA"),
                          SessionKey.derive(identity: TerminalIdentity(adapterID: "kitty", handle: "1"), sessionID: "sB"))
    }
}
