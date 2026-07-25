import Foundation

/// Codex CLI's tool catalog: `Bash` (shell) → command, `apply_patch` → diff, else raw.
public struct CodexToolRenderer: ToolRendering {
    public init() {}

    public func render(tool: String, input: [String: Any]) -> ToolPreview {
        switch tool {
        case "Bash", "shell":
            return .command((input["command"] as? String) ?? "")
        case "apply_patch":
            // Codex delivers the patch body under tool_input.command (fallbacks kept for safety).
            let patch = (input["command"] as? String) ?? (input["patch"] as? String) ?? (input["input"] as? String) ?? ""
            let file = Self.patchedFile(patch)
            let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).compactMap { raw -> DiffLine? in
                let s = String(raw)
                if s.hasPrefix("+") && !s.hasPrefix("+++") { return DiffLine(kind: .added, text: String(s.dropFirst())) }
                if s.hasPrefix("-") && !s.hasPrefix("---") { return DiffLine(kind: .removed, text: String(s.dropFirst())) }
                return nil
            }
            return lines.isEmpty ? .raw(patch.isEmpty ? tool : patch) : .diff(file: file, lines: lines)
        default:
            let name = (input["command"] as? String) ?? (input["file_path"] as? String) ?? tool
            return .raw(name)
        }
    }

    public func actionLabel(toolName: String?, input: [String: Any]?) -> String? {
        guard let tool = toolName else { return nil }
        let input = input ?? [:]
        switch tool {
        case "Bash", "shell":
            let cmd = (input["command"] as? String) ?? ""
            let firstLine = cmd.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? cmd
            return firstLine.isEmpty ? "Bash:" : "Bash: \(firstLine)"
        case "apply_patch":
            let file = Self.patchedFile((input["command"] as? String) ?? (input["patch"] as? String) ?? (input["input"] as? String) ?? "")
            return file.isEmpty ? "Edit" : "Edit \((file as NSString).lastPathComponent)"
        default:
            return tool
        }
    }

    /// Pull the first target path out of an apply_patch body ("*** Update File: <path>").
    static func patchedFile(_ patch: String) -> String {
        for line in patch.split(separator: "\n") {
            for marker in ["*** Update File: ", "*** Add File: ", "*** Delete File: "] where line.hasPrefix(marker) {
                return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }
}
