import Foundation

public enum CodexPaths {
    public static var codexDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }
    /// Codex reads the same {"hooks":{…}} JSON shape Claude uses, from ~/.codex/hooks.json.
    public static var hooksURL: URL { codexDir.appendingPathComponent("hooks.json") }
}
