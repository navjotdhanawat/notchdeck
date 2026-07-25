import Foundation

public enum AllowScope: Sendable, Equatable { case once, session }

public enum Decision: Sendable, Equatable {
    case allow(scope: AllowScope)
    case deny(reason: String?)
    case passthrough
    /// AskUserQuestion answer: question text → chosen option label (single-select).
    case answer(answers: [String: String])
}

public struct QuestionOption: Sendable, Equatable {
    public let label: String
    public let description: String?
    public init(label: String, description: String?) { self.label = label; self.description = description }
}

public struct QuestionSpec: Sendable, Equatable {
    public let question: String
    public let header: String?
    public let options: [QuestionOption]
    public let multiSelect: Bool
    public init(question: String, header: String?, options: [QuestionOption], multiSelect: Bool) {
        self.question = question; self.header = header; self.options = options; self.multiSelect = multiSelect
    }
}

public enum DecisionKind: Sendable, Equatable {
    case toolPermission(tool: String, preview: ToolPreview)
    case planApproval(text: String)
    case question(questions: [QuestionSpec])
}

public struct DecisionRequest: Identifiable, Sendable, Equatable {
    public let id: String
    public let sessionKey: String
    public let kind: DecisionKind
    public let receivedAt: Date
    public init(id: String, sessionKey: String, kind: DecisionKind, receivedAt: Date) {
        self.id = id; self.sessionKey = sessionKey; self.kind = kind; self.receivedAt = receivedAt
    }
}

/// Claude Code's tool → DecisionRequest mapping: AskUserQuestion → question,
/// ExitPlanMode → plan approval, everything else → a tool-permission card.
public struct ClaudeDecisionMapper: DecisionMapping {
    private let renderer: ToolRendering
    public init(renderer: ToolRendering = ClaudeToolRenderer()) { self.renderer = renderer }

    public func request(from event: HookEvent, id: String, sessionKey: String) -> DecisionRequest? {
        guard let tool = event.toolName else { return nil }
        let input = event.toolInputDict ?? [:]
        let kind: DecisionKind
        if tool == "AskUserQuestion" {
            kind = .question(questions: Self.parseQuestions(input))
        } else if tool == "ExitPlanMode" {
            kind = .planApproval(text: (input["plan"] as? String) ?? "")
        } else {
            kind = .toolPermission(tool: tool, preview: renderer.render(tool: tool, input: input))
        }
        return DecisionRequest(id: id, sessionKey: sessionKey, kind: kind, receivedAt: event.receivedAt)
    }

    private static func parseQuestions(_ input: [String: Any]) -> [QuestionSpec] {
        let raw = (input["questions"] as? [[String: Any]]) ?? []
        return raw.map { q in
            let opts = ((q["options"] as? [[String: Any]]) ?? []).map {
                QuestionOption(label: ($0["label"] as? String) ?? "", description: $0["description"] as? String)
            }
            return QuestionSpec(
                question: (q["question"] as? String) ?? "",
                header: q["header"] as? String,
                options: opts,
                multiSelect: (q["multiSelect"] as? Bool) ?? false
            )
        }
    }
}
