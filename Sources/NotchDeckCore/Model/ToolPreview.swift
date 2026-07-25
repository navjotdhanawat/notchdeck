import Foundation

public struct DiffLine: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case context, added, removed }
    public let kind: Kind
    public let text: String
    public init(kind: Kind, text: String) { self.kind = kind; self.text = text }
}

/// A renderable view of a tool's proposed action for a permission card.
public enum ToolPreview: Sendable, Equatable {
    case diff(file: String, lines: [DiffLine])   // Edit / MultiEdit / Write
    case command(String)                          // Bash
    case raw(String)                              // anything else
}
