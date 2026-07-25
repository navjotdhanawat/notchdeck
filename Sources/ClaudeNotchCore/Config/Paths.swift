import Foundation

public enum Paths {
    public static var appSupportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ClaudeNotch", isDirectory: true)
    }
    public static var bridgeConfigURL: URL { appSupportDir.appendingPathComponent("bridge.json") }
    public static var claudeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }
}
