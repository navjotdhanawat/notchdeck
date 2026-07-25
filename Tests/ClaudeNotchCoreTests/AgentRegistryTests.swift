import XCTest
@testable import ClaudeNotchCore

/// Minimal fake proving the seam works without any real agent.
private struct FakeProvider: AgentProvider {
    let agentID: String
    var displayName: String { agentID }
    let present: Bool
    func isPresent() -> Bool { present }
    var installProfile: AgentInstallProfile {
        AgentInstallProfile(settingsURL: URL(fileURLWithPath: "/tmp/\(agentID).json"),
                            backupFilename: "b", monitorSpecs: [], decisionSpecs: [], versionGate: nil)
    }
    var decisionMapper: DecisionMapping { ClaudeDecisionMapper() }
    var transcriptParser: TranscriptParsing { ClaudeTranscriptParser() }
    var costEstimator: CostEstimator { ClaudePricing() }
    var toolRenderer: ToolRendering { ClaudeToolRenderer() }
}

final class AgentRegistryTests: XCTestCase {
    func testResolvesKnownAgent() {
        let reg = AgentRegistry([FakeProvider(agentID: "codex", present: true),
                                 ClaudeAgentProvider()])
        XCTAssertEqual(reg.provider(for: "codex").agentID, "codex")
        XCTAssertEqual(reg.provider(for: "claude").agentID, "claude")
    }

    func testUnknownOrMissingResolvesToClaude() {
        let reg = AgentRegistry([FakeProvider(agentID: "codex", present: true), ClaudeAgentProvider()])
        XCTAssertEqual(reg.provider(for: "gemini").agentID, "claude")
        XCTAssertEqual(reg.provider(for: "").agentID, "claude")
    }

    func testPresentProvidersFiltersByPresence() {
        let reg = AgentRegistry([FakeProvider(agentID: "codex", present: false), ClaudeAgentProvider()])
        XCTAssertEqual(reg.presentProviders().map(\.agentID), ["claude"])
    }

    func testDefaultProvidesSharedEncoderAndMapper() {
        // Parse-and-compare: DecisionEncoder doesn't sort keys, so byte-comparing two
        // independent serializations is nondeterministic. Assert semantic equality.
        let p = ClaudeAgentProvider()
        let a = (try? JSONSerialization.jsonObject(with: p.decisionEncoder.stdoutJSON(for: .allow(scope: .once))!)) as? NSDictionary
        let b = (try? JSONSerialization.jsonObject(with: DecisionEncoder.stdoutJSON(for: .allow(scope: .once))!)) as? NSDictionary
        XCTAssertEqual(a, b)
        XCTAssertNoThrow(try p.eventMapper.decode(Data(#"{"session_id":"s"}"#.utf8), name: .stop, now: Date()))
    }
}
