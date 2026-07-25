import Foundation

/// Model + accumulated tokens + estimated USD cost for a session, derived from its transcript.
public struct SessionUsage: Sendable, Equatable {
    public var model: String?      // raw id, e.g. "claude-opus-4-8"; nil until first assistant turn
    public var tokens: TokenUsage
    public var costUSD: Double?    // nil when the model price is unknown → render tokens only

    public init(model: String? = nil, tokens: TokenUsage = TokenUsage(), costUSD: Double? = nil) {
        self.model = model
        self.tokens = tokens
        self.costUSD = costUSD
    }
}
