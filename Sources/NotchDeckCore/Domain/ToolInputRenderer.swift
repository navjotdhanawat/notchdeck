import Foundation

public enum ToolInputRenderer {
    public static func render(tool: String, input: [String: Any]) -> ToolPreview {
        switch tool {
        case "Edit":
            let file = (input["file_path"] as? String) ?? ""
            let removed = splitLines(input["old_string"] as? String).map { DiffLine(kind: .removed, text: $0) }
            let added = splitLines(input["new_string"] as? String).map { DiffLine(kind: .added, text: $0) }
            return .diff(file: file, lines: removed + added)
        case "MultiEdit":
            let file = (input["file_path"] as? String) ?? ""
            var lines: [DiffLine] = []
            for edit in (input["edits"] as? [[String: Any]]) ?? [] {
                lines += splitLines(edit["old_string"] as? String).map { DiffLine(kind: .removed, text: $0) }
                lines += splitLines(edit["new_string"] as? String).map { DiffLine(kind: .added, text: $0) }
            }
            return .diff(file: file, lines: lines)
        case "Write":
            let file = (input["file_path"] as? String) ?? ""
            return .diff(file: file, lines: splitLines(input["content"] as? String).map { DiffLine(kind: .added, text: $0) })
        case "Bash":
            return .command((input["command"] as? String) ?? "")
        default:
            let name = (input["file_path"] as? String) ?? (input["command"] as? String) ?? tool
            return .raw(name)
        }
    }

    private static func splitLines(_ s: String?) -> [String] {
        guard let s, !s.isEmpty else { return [] }
        return s.components(separatedBy: "\n")
    }
}

extension ToolInputRenderer {
    /// Short, human-readable label of what a tool call is doing, for the glance row.
    /// Returns nil when there is no tool.
    public static func actionLabel(toolName: String?, input: [String: Any]?) -> String? {
        guard let tool = toolName else { return nil }
        let input = input ?? [:]
        func base(_ key: String) -> String {
            guard let p = input[key] as? String, !p.isEmpty else { return "" }
            return (p as NSString).lastPathComponent
        }
        func labeled(_ verb: String, _ name: String) -> String {
            name.isEmpty ? verb : "\(verb) \(name)"
        }
        switch tool {
        case "Edit", "MultiEdit": return labeled("Edit", base("file_path"))
        case "Write":             return labeled("Write", base("file_path"))
        case "Read":              return labeled("Read", base("file_path"))
        case "Bash":
            let cmd = (input["command"] as? String) ?? ""
            let firstLine = cmd.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? cmd
            return labeled("Bash:", firstLine)
        case "Grep":         return labeled("Search", (input["pattern"] as? String) ?? "")
        case "Glob":         return labeled("Find", (input["pattern"] as? String) ?? "")
        case "Task":         return labeled("Task:", (input["description"] as? String) ?? "subagent")
        case "WebFetch":     return labeled("Fetch", (input["url"] as? String) ?? "")
        case "WebSearch":    return "Search web"
        case "ExitPlanMode": return "Review plan"
        default:             return tool
        }
    }
}

/// Claude Code's tool catalog as a `ToolRendering` seam. Delegates to `ToolInputRenderer`,
/// which stays the pure implementation of Claude's tool-name/input-key conventions.
public struct ClaudeToolRenderer: ToolRendering {
    public init() {}
    public func render(tool: String, input: [String: Any]) -> ToolPreview {
        ToolInputRenderer.render(tool: tool, input: input)
    }
    public func actionLabel(toolName: String?, input: [String: Any]?) -> String? {
        ToolInputRenderer.actionLabel(toolName: toolName, input: input)
    }
}
