import Foundation

// MARK: - Per-concern agent seams (pure). One AgentProvider (see AgentProvider.swift) vends these.

/// Turns a raw hook payload into a `HookEvent`. Default = the shared Claude/Codex field layout.
public protocol HookEventMapping: Sendable {
    func decode(_ data: Data, name: HookEventName, now: Date) throws -> HookEvent
}

/// Turns a decoded decision-bearing event into a `DecisionRequest`, or nil to pass through.
public protocol DecisionMapping: Sendable {
    func request(from event: HookEvent, id: String, sessionKey: String) -> DecisionRequest?
}

/// Encodes a `Decision` into the agent's hook-stdout contract. Default = the shared
/// `hookSpecificOutput` envelope (identical for Claude and Codex).
public protocol DecisionEncoding: Sendable {
    func stdoutJSON(for decision: Decision) -> Data?
    func answerStdoutJSON(_ answers: [String: String], originalToolInput: Data?) -> Data?
}

/// Parses a transcript JSONL chunk into (latest model, summed token usage).
public protocol TranscriptParsing: Sendable {
    func parse(_ chunk: String) -> (model: String?, usage: TokenUsage)
}

/// Renders a tool call for the permission card and the glance-row action label.
public protocol ToolRendering: Sendable {
    func render(tool: String, input: [String: Any]) -> ToolPreview
    func actionLabel(toolName: String?, input: [String: Any]?) -> String?
}

// MARK: - Shared defaults (used verbatim by both Claude and Codex)

/// Default inbound decode: Claude and Codex share the same hook field names
/// (`session_id`/`cwd`/`tool_name`/`tool_input`/`transcript_path` + injected `agent_id`).
public struct DefaultHookEventMapper: HookEventMapping {
    public init() {}
    public func decode(_ data: Data, name: HookEventName, now: Date) throws -> HookEvent {
        try HookEvent.decode(data, name: name, now: now)
    }
}

/// Default decision encoder: the `hookSpecificOutput` envelope Claude and Codex both accept.
public struct HookSpecificOutputEncoder: DecisionEncoding {
    public init() {}
    public func stdoutJSON(for decision: Decision) -> Data? {
        DecisionEncoder.stdoutJSON(for: decision)
    }
    public func answerStdoutJSON(_ answers: [String: String], originalToolInput: Data?) -> Data? {
        DecisionEncoder.answerStdoutJSON(answers, originalToolInput: originalToolInput)
    }
}
