// Sources/ClaudeNotchCore/Domain/TranscriptParser.swift
import Foundation

/// The result of scanning newly-appended transcript bytes.
public struct TranscriptScan: Sendable, Equatable {
    public var newOffset: Int
    public var model: String?
    public var usageDelta: TokenUsage

    public init(newOffset: Int, model: String? = nil, usageDelta: TokenUsage = TokenUsage()) {
        self.newOffset = newOffset
        self.model = model
        self.usageDelta = usageDelta
    }
}

/// Pure parser for Claude Code transcript JSONL. Sums assistant `message.usage` token buckets
/// and reports the latest assistant `message.model`. Tolerant of unknown/malformed lines
/// (skips anything it can't read), matching `HookEvent.decode`'s posture.
///
/// Observed schema (Claude Code, 2026-07): each assistant line is
/// `{"type":"assistant","message":{"model":"claude-…","usage":{"input_tokens":…,
///  "output_tokens":…,"cache_creation_input_tokens":…,"cache_read_input_tokens":…}}}`.
public enum TranscriptParser {
    public static func parse(_ chunk: String) -> (model: String?, usage: TokenUsage) {
        var model: String? = nil
        var total = TokenUsage()
        for line in chunk.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  (obj["type"] as? String) == "assistant",
                  let message = obj["message"] as? [String: Any] else { continue }
            if let m = message["model"] as? String { model = m }
            if let u = message["usage"] as? [String: Any] {
                total = total + TokenUsage(
                    input: (u["input_tokens"] as? Int) ?? 0,
                    output: (u["output_tokens"] as? Int) ?? 0,
                    cacheCreation: (u["cache_creation_input_tokens"] as? Int) ?? 0,
                    cacheRead: (u["cache_read_input_tokens"] as? Int) ?? 0
                )
            }
        }
        return (model, total)
    }
}

/// Claude Code's transcript schema as a `TranscriptParsing` seam. Delegates to the pure
/// `TranscriptParser` enum, which stays the implementation of Claude's `message.usage` layout.
public struct ClaudeTranscriptParser: TranscriptParsing {
    public init() {}
    public func parse(_ chunk: String) -> (model: String?, usage: TokenUsage) {
        TranscriptParser.parse(chunk)
    }
}
