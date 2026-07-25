import Foundation

/// One installed hook entry, agent-neutral. `args` is the argv appended after the quoted
/// helper path in the written command (e.g. "--agent claude SessionStart").
public struct HookSpec: Sendable {
    public let event: String
    public let matcher: String
    public let args: String
    public let isAsync: Bool
    public let timeout: Int?
    public init(event: String, matcher: String, args: String, isAsync: Bool, timeout: Int?) {
        self.event = event; self.matcher = matcher; self.args = args
        self.isAsync = isAsync; self.timeout = timeout
    }
}

/// A CLI version floor for enabling sync (decision) hooks. `binary` is run as
/// `/usr/bin/env <binary> --version`. Nil gate ⇒ decisions always enabled when present.
public struct VersionGate: Sendable {
    public let binary: String
    public let minVersion: (Int, Int, Int)
    public init(binary: String, minVersion: (Int, Int, Int)) {
        self.binary = binary; self.minVersion = minVersion
    }
}

/// Everything an agent needs to install its hooks: where, the backup name, the monitor and
/// decision hook specs, and an optional version gate for the decision specs.
public struct AgentInstallProfile: Sendable {
    public let settingsURL: URL
    public let backupFilename: String
    public let monitorSpecs: [HookSpec]
    public let decisionSpecs: [HookSpec]
    public let versionGate: VersionGate?
    public init(settingsURL: URL, backupFilename: String,
                monitorSpecs: [HookSpec], decisionSpecs: [HookSpec], versionGate: VersionGate?) {
        self.settingsURL = settingsURL; self.backupFilename = backupFilename
        self.monitorSpecs = monitorSpecs; self.decisionSpecs = decisionSpecs
        self.versionGate = versionGate
    }
}
