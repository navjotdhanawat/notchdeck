import Foundation

/// The four token buckets Claude Code reports per assistant turn in `message.usage`.
public struct TokenUsage: Sendable, Equatable {
    public var input: Int
    public var output: Int
    public var cacheCreation: Int
    public var cacheRead: Int

    public init(input: Int = 0, output: Int = 0, cacheCreation: Int = 0, cacheRead: Int = 0) {
        self.input = input
        self.output = output
        self.cacheCreation = cacheCreation
        self.cacheRead = cacheRead
    }

    public var total: Int { input + output + cacheCreation + cacheRead }

    public static func + (a: TokenUsage, b: TokenUsage) -> TokenUsage {
        TokenUsage(input: a.input + b.input,
                   output: a.output + b.output,
                   cacheCreation: a.cacheCreation + b.cacheCreation,
                   cacheRead: a.cacheRead + b.cacheRead)
    }
}
