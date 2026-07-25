import Foundation

/// Encodes a Decision into the exact `PermissionRequest` hook stdout contract.
/// Returns nil for `.passthrough` — the caller must then emit NOTHING so Claude
/// Code shows its normal permission dialog.
public enum DecisionEncoder {
    public static func stdoutJSON(for decision: Decision) -> Data? {
        let behavior: [String: Any]
        switch decision {
        case .allow:
            behavior = ["behavior": "allow"]
        case .deny(let reason):
            behavior = ["behavior": "deny", "message": reason ?? "Denied from ClaudeNotch"]
        case .passthrough:
            return nil
        case .answer:
            return nil   // answers use the PreToolUse envelope — see answerStdoutJSON(_:originalToolInput:)
        }
        let root: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": behavior
            ]
        ]
        return try? JSONSerialization.data(withJSONObject: root)
    }

    /// Encodes an AskUserQuestion answer for the `PreToolUse` hook stdout contract:
    /// `permissionDecision:"allow"` + `updatedInput` = the original tool_input merged with `answers`.
    public static func answerStdoutJSON(_ answers: [String: String], originalToolInput: Data?) -> Data? {
        var updatedInput: [String: Any] = [:]
        if let originalToolInput,
           let obj = try? JSONSerialization.jsonObject(with: originalToolInput) as? [String: Any] {
            updatedInput = obj
        }
        updatedInput["answers"] = answers
        let root: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "updatedInput": updatedInput
            ]
        ]
        return try? JSONSerialization.data(withJSONObject: root)
    }
}
