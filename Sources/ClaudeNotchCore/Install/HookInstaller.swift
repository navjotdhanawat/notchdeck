import Foundation

public struct HookInstaller {
    public let helperPath: String
    private let specs: [HookSpec]
    private let backupFilename: String

    public init(helperPath: String, specs: [HookSpec],
                backupFilename: String = "settings.json.claudenotch-backup") {
        self.helperPath = helperPath
        self.specs = specs
        self.backupFilename = backupFilename
    }

    private func command(args: String) -> String {
        // Quote the helper path so spaced install paths (e.g. "/My Apps/…") survive
        // Claude Code's shell word-splitting; otherwise every hook silently breaks.
        "\"\(helperPath)\" \(args)"
    }

    private func isOurs(_ hook: [String: Any]) -> Bool {
        // Commands are stored with the helper path quoted; match that exact prefix.
        (hook["command"] as? String)?.hasPrefix("\"\(helperPath)\"") ?? false
    }

    private func loadRoot(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "HookInstaller", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "settings.json is not a valid JSON object"])
        }
        return obj
    }

    private func save(_ root: [String: Any], to url: URL) throws {
        // backup existing
        if FileManager.default.fileExists(atPath: url.path) {
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent(backupFilename)
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root,
                                              options: [.prettyPrinted, .sortedKeys])
        // JSONSerialization escapes forward slashes (/ -> \/), which cosmetically mangles the
        // user's settings.json. JSON only ever uses \/ for an escaped slash, so unescaping is
        // lossless. We keep [String: Any] + JSONSerialization to round-trip arbitrary unknown
        // user JSON, which rules out a Codable/JSONEncoder .withoutEscapingSlashes path.
        let unescaped = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "\\/", with: "/")
        try Data(unescaped.utf8).write(to: url, options: .atomic) // temp file + rename
    }

    /// Remove our entries from a hooks dict, dropping now-empty matcher groups and event arrays.
    private func stripOurs(_ hooks: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (event, value) in hooks {
            guard var groups = value as? [[String: Any]] else { result[event] = value; continue }
            groups = groups.compactMap { group in
                guard var inner = group["hooks"] as? [[String: Any]] else { return group }
                inner = inner.filter { !isOurs($0) }
                if inner.isEmpty { return nil }
                var g = group; g["hooks"] = inner; return g
            }
            if !groups.isEmpty { result[event] = groups }
        }
        return result
    }

    public func install(into url: URL) throws {
        var root = try loadRoot(url)
        var hooks = (root["hooks"] as? [String: Any]) ?? [:]
        hooks = stripOurs(hooks) // idempotent: remove any prior ours, then re-add fresh

        for spec in specs {
            var groups = (hooks[spec.event] as? [[String: Any]]) ?? []
            var ourHook: [String: Any] = [
                "type": "command",
                "command": command(args: spec.args)
            ]
            if spec.isAsync { ourHook["async"] = true }
            if let t = spec.timeout { ourHook["timeout"] = t }

            if let idx = groups.firstIndex(where: { ($0["matcher"] as? String) == spec.matcher }) {
                var group = groups[idx]
                var inner = (group["hooks"] as? [[String: Any]]) ?? []
                inner.append(ourHook)
                group["hooks"] = inner
                groups[idx] = group
            } else {
                groups.append(["matcher": spec.matcher, "hooks": [ourHook]])
            }
            hooks[spec.event] = groups
        }
        root["hooks"] = hooks
        try save(root, to: url)
    }

    public func uninstall(from url: URL) throws {
        var root = try loadRoot(url)
        guard let hooks = root["hooks"] as? [String: Any] else { return }
        let stripped = stripOurs(hooks)
        if stripped.isEmpty { root.removeValue(forKey: "hooks") } else { root["hooks"] = stripped }
        try save(root, to: url)
    }

    public func status(url: URL) throws -> Bool {
        let hooks = (try loadRoot(url)["hooks"] as? [String: Any]) ?? [:]
        for (_, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            for group in groups {
                let inner = (group["hooks"] as? [[String: Any]]) ?? []
                if inner.contains(where: isOurs) { return true }
            }
        }
        return false
    }
}
