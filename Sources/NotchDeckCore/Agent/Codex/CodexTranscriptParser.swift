import Foundation

/// Parses Codex CLI rollout JSONL. Each line is `{"type","payload","timestamp"}`.
/// - model: the `turn_context` payload's `model` field.
/// - usage: each `event_msg` payload with `type == "token_count"` carries `info.last_token_usage`
///   (the per-turn delta). Codex/OpenAI buckets map onto our four-bucket TokenUsage as:
///   input = input_tokens − cached_input_tokens (uncached), output = output_tokens (which already
///   includes reasoning_output_tokens per the OpenAI Responses API / Codex `blended_total`),
///   cacheRead = cached_input_tokens, cacheCreation = 0 (OpenAI has no cache-write charge).
///   Summing last_token_usage across events accumulates correctly via UsageTracker. Schema
///   verified against ~/.codex rollouts + the openai/codex protocol source.
public struct CodexTranscriptParser: TranscriptParsing {
    public init() {}
    public func parse(_ chunk: String) -> (model: String?, usage: TokenUsage) {
        var model: String? = nil
        var total = TokenUsage()
        for line in chunk.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let payload = obj["payload"] as? [String: Any] else { continue }
            if (obj["type"] as? String) == "turn_context", let m = payload["model"] as? String {
                model = m   // only turn_context carries the active model
            }
            if (payload["type"] as? String) == "token_count",
               let info = payload["info"] as? [String: Any],
               let last = info["last_token_usage"] as? [String: Any] {
                let input = (last["input_tokens"] as? Int) ?? 0
                let cached = (last["cached_input_tokens"] as? Int) ?? 0
                let output = (last["output_tokens"] as? Int) ?? 0   // already includes reasoning_output_tokens
                total = total + TokenUsage(
                    input: max(0, input - cached),      // uncached input (input_tokens includes cached)
                    output: output,
                    cacheCreation: 0,
                    cacheRead: cached
                )
            }
        }
        return (model, total)
    }
}
