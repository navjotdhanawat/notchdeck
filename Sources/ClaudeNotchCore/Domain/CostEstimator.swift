import Foundation

/// Estimates USD cost for token usage under a given model. Returns nil for unknown models.
public protocol CostEstimator: Sendable {
    func cost(model: String?, tokens: TokenUsage) -> Double?
}

/// Claude/Anthropic per-model, per-bucket pricing (USD per million tokens).
/// Prices reflect Anthropic public pricing as of 2026-07 — verify and update when prices change.
public struct ClaudePricing: CostEstimator {
    struct Price: Sendable { let input, output, cacheWrite, cacheRead: Double } // USD / MTok

    private static let table: [String: Price] = [
        "claude-opus-4-8":  Price(input: 15, output: 75, cacheWrite: 18.75, cacheRead: 1.5),
        "claude-opus-4-7":  Price(input: 15, output: 75, cacheWrite: 18.75, cacheRead: 1.5),
        "claude-sonnet-5":  Price(input: 3,  output: 15, cacheWrite: 3.75,  cacheRead: 0.3),
        "claude-haiku-4-5": Price(input: 1,  output: 5,  cacheWrite: 1.25,  cacheRead: 0.1),
        "claude-fable-5":   Price(input: 3,  output: 15, cacheWrite: 3.75,  cacheRead: 0.3),
    ]

    public init() {}

    public func cost(model: String?, tokens: TokenUsage) -> Double? {
        guard let model, let p = Self.match(model) else { return nil }
        func mtok(_ n: Int) -> Double { Double(n) / 1_000_000 }
        return mtok(tokens.input) * p.input
             + mtok(tokens.output) * p.output
             + mtok(tokens.cacheCreation) * p.cacheWrite
             + mtok(tokens.cacheRead) * p.cacheRead
    }

    /// Exact id match, else known-prefix match (ids sometimes carry a date/suffix).
    private static func match(_ model: String) -> Price? {
        if let p = table[model] { return p }
        return table.first(where: { model.hasPrefix($0.key) })?.value
    }
}
