import XCTest
@testable import ClaudeNotchCore

final class HookInstallerTests: XCTestCase {
    private func tmpURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("settings-\(UUID().uuidString).json")
    }
    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent()
            .appendingPathComponent("settings.json.claudenotch-backup"))
    }
    private func read(_ url: URL) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }
    private func installer(_ helper: String, decisions: Bool) -> HookInstaller {
        let p = ClaudeAgentProvider().installProfile
        return HookInstaller(helperPath: helper,
                             specs: p.monitorSpecs + (decisions ? p.decisionSpecs : []),
                             backupFilename: p.backupFilename)
    }

    func testInstallIntoMissingFileCreatesHooks() throws {
        let url = tmpURL(); defer { remove(url) }
        let inst = installer("/App/notch-bridge", decisions: false)
        try inst.install(into: url)
        XCTAssertTrue(try inst.status(url: url))
        let hooks = try read(url)["hooks"] as! [String: Any]
        XCTAssertNotNil(hooks["SessionStart"])
        XCTAssertNotNil(hooks["Stop"])
        let notif = hooks["Notification"] as! [[String: Any]]
        let matchers = notif.map { $0["matcher"] as! String }
        XCTAssertTrue(matchers.contains("permission_prompt"))
    }

    func testInstallPreservesExistingUserHooks() throws {
        let url = tmpURL(); defer { remove(url) }
        let existing = #"""
        {"model":"opus","hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"/usr/bin/my-own-thing"}]}]}}
        """#
        try Data(existing.utf8).write(to: url)
        try installer("/App/notch-bridge", decisions: false).install(into: url)

        let root = try read(url)
        XCTAssertEqual(root["model"] as? String, "opus")
        let stop = (root["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        XCTAssertEqual(stop.count, 1)
        let group = stop[0]
        XCTAssertEqual(group["matcher"] as? String, "*")
        let cmds = (group["hooks"] as! [[String: Any]]).map { $0["command"] as! String }
        XCTAssertTrue(cmds.contains("/usr/bin/my-own-thing"))
        XCTAssertTrue(cmds.contains { $0.hasPrefix("\"/App/notch-bridge\"") })
    }

    func testUninstallRemovesOnlyOurs() throws {
        let url = tmpURL(); defer { remove(url) }
        let existing = #"""
        {"hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"/usr/bin/my-own-thing"}]}]}}
        """#
        try Data(existing.utf8).write(to: url)
        let inst = installer("/App/notch-bridge", decisions: false)
        try inst.install(into: url)
        try inst.uninstall(from: url)

        XCTAssertFalse(try inst.status(url: url))
        let stop = (try read(url)["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        let cmds = stop.flatMap { ($0["hooks"] as! [[String: Any]]).map { $0["command"] as! String } }
        XCTAssertEqual(cmds, ["/usr/bin/my-own-thing"])
    }

    func testInstallIsIdempotent() throws {
        let url = tmpURL(); defer { remove(url) }
        let inst = installer("/App/notch-bridge", decisions: false)
        try inst.install(into: url)
        try inst.install(into: url)
        let hooks = try read(url)["hooks"] as! [String: Any]
        let stop = hooks["Stop"] as! [[String: Any]]
        let ours = stop.flatMap { ($0["hooks"] as! [[String: Any]]) }
            .filter { ($0["command"] as! String).hasPrefix("\"/App/notch-bridge\"") }
        XCTAssertEqual(ours.count, 1)

        let notif = hooks["Notification"] as! [[String: Any]]
        XCTAssertEqual(notif.count, 2)
    }

    func testPermissionRequestInstalledWhenDecisionsEnabled() throws {
        let url = tmpURL(); defer { remove(url) }
        try installer("/App/notch-bridge", decisions: true).install(into: url)
        let hooks = try read(url)["hooks"] as! [String: Any]
        let pr = hooks["PermissionRequest"] as! [[String: Any]]
        let matchers = pr.compactMap { $0["matcher"] as? String }.sorted()
        XCTAssertEqual(matchers, ["*", "ExitPlanMode"])
        for group in pr {
            let inner = (group["hooks"] as! [[String: Any]]).first { ($0["command"] as? String)?.hasPrefix("\"/App/notch-bridge\"") == true }!
            XCTAssertNil(inner["async"])
            XCTAssertEqual(inner["timeout"] as? Int, 600)
            XCTAssertEqual(inner["command"] as? String, "\"/App/notch-bridge\" --agent claude decide PermissionRequest")
        }
    }

    func testPermissionRequestOmittedWhenDecisionsDisabled() throws {
        let url = tmpURL(); defer { remove(url) }
        try installer("/App/notch-bridge", decisions: false).install(into: url)
        let hooks = try read(url)["hooks"] as! [String: Any]
        XCTAssertNil(hooks["PermissionRequest"])
    }
}
