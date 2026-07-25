import Foundation

/// OpenAI/Codex per-model pricing (USD per million tokens). No cache-write bucket; the discounted
/// cached-input rate maps to `cacheRead`. VERIFY rates + model ids against current OpenAI pricing.
public struct OpenAIPricing: CostEstimator {
    struct Price: Sendable { let input, output, cacheRead: Double }   // USD / MTok

    private static let table: [String: Price] = [
        "gpt-5-codex": Price(input: 1.25, output: 10, cacheRead: 0.125),
        "gpt-5":       Price(input: 1.25, output: 10, cacheRead: 0.125),
        "gpt-5-mini":  Price(input: 0.25, output: 2,  cacheRead: 0.025),
        "o4-mini":     Price(input: 1.1,  output: 4.4, cacheRead: 0.275),
    ]

    public init() {}

    public func cost(model: String?, tokens: TokenUsage) -> Double? {
        guard let model, let p = Self.match(model) else { return nil }
        func mtok(_ n: Int) -> Double { Double(n) / 1_000_000 }
        return mtok(tokens.input) * p.input
             + mtok(tokens.output) * p.output
             + mtok(tokens.cacheRead) * p.cacheRead
        // cacheCreation is always 0 for Codex (OpenAI has no cache-write charge).
    }

    private static func match(_ model: String) -> Price? {
        if let p = table[model] { return p }
        // Longest matching key wins — deterministic; avoids "gpt-5-mini-2026-xx" matching both keys.
        return table.keys.sorted { $0.count > $1.count }.first(where: { model.hasPrefix($0) }).map { table[$0]! }
    }
}
