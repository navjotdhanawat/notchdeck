import Foundation

public enum ClaudeNotchCore { public static let version = "0.1.0" }

public enum HookEventName: String, Sendable {
    case sessionStart = "SessionStart"
    case preToolUse = "PreToolUse"
    case notification = "Notification"
    case stop = "Stop"
    case stopFailure = "StopFailure"
    case sessionEnd = "SessionEnd"
    case permissionRequest = "PermissionRequest"
}

public struct HookEnv: Sendable, Equatable {
    /// Raw environment variables forwarded by the bridge (e.g. ITERM_SESSION_ID, WEZTERM_PANE).
    public var values: [String: String]
    public var pid: Int?

    public init(values: [String: String] = [:], pid: Int? = nil) {
        self.values = values
        self.pid = pid
    }

    /// Convenience for a standard cross-terminal variable.
    public var termProgram: String? { values["TERM_PROGRAM"] }
}

public enum HookDecodeError: Error { case notAnObject, missingSessionID }

public struct HookEvent: Sendable, Equatable {
    public let name: HookEventName
    public let agentID: String
    public let sessionID: String
    public let cwd: String
    public let matcher: String?
    public let toolName: String?
    public let transcriptPath: String?
    public let env: HookEnv
    public let toolInput: Data?
    public let receivedAt: Date

    public init(name: HookEventName, agentID: String = "claude", sessionID: String, cwd: String, matcher: String?,
                toolName: String?, transcriptPath: String?, env: HookEnv, toolInput: Data? = nil, receivedAt: Date) {
        self.name = name; self.agentID = agentID; self.sessionID = sessionID; self.cwd = cwd; self.matcher = matcher
        self.toolName = toolName; self.transcriptPath = transcriptPath; self.env = env
        self.toolInput = toolInput; self.receivedAt = receivedAt
    }

    /// Parsed tool_input object, or nil if absent/malformed.
    public var toolInputDict: [String: Any]? {
        guard let toolInput else { return nil }
        return (try? JSONSerialization.jsonObject(with: toolInput)) as? [String: Any]
    }

    /// Resilient decode via JSONSerialization so unknown/extra Claude Code fields never break us.
    public static func decode(_ data: Data, name: HookEventName, now: Date) throws -> HookEvent {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookDecodeError.notAnObject
        }
        guard let sessionID = obj["session_id"] as? String, !sessionID.isEmpty else {
            throw HookDecodeError.missingSessionID
        }
        var values: [String: String] = [:]
        if let e = obj["env"] as? [String: Any] {
            for (k, v) in e {
                if let s = v as? String { values[k] = s }
                else if let n = v as? Int { values[k] = String(n) }
            }
        }
        let env = HookEnv(values: values, pid: values["PID"].flatMap(Int.init))
        var toolInputData: Data? = nil
        if let ti = obj["tool_input"] {
            toolInputData = try? JSONSerialization.data(withJSONObject: ti)
        }
        let agentID = (obj["agent_id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "claude"
        return HookEvent(
            name: name,
            agentID: agentID,
            sessionID: sessionID,
            cwd: (obj["cwd"] as? String) ?? "",
            matcher: obj["matcher"] as? String,
            toolName: obj["tool_name"] as? String,
            transcriptPath: obj["transcript_path"] as? String,
            env: env,
            toolInput: toolInputData,
            receivedAt: now
        )
    }

    /// Cheaply read `agent_id` from a raw hook payload without a full decode, so the
    /// transport can pick the right provider before decoding. Defaults to "claude".
    public static func peekAgentID(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = obj["agent_id"] as? String, !id.isEmpty else { return "claude" }
        return id
    }
}
