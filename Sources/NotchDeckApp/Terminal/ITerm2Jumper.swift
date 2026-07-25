import Foundation
import AppKit
import NotchDeckCore

/// Focuses a specific iTerm2 window→tab→split by matching the AppleScript session `id`
/// (the UUID suffix of ITERM_SESSION_ID).
public struct ITerm2Jumper: TerminalJumping {
    public init() {}
    public let adapterID = "iterm2"

    public func jump(to identity: TerminalIdentity) async -> JumpResult {
        guard let uuid = identity.handle, !uuid.isEmpty else { return .failed("no iTerm handle") }
        let script = Self.script(uuid: uuid)
        return await MainActor.run {
            var errorInfo: NSDictionary?
            guard let apple = NSAppleScript(source: script) else { return .failed("bad script") }
            let out = apple.executeAndReturnError(&errorInfo)
            if let errorInfo { return .failed("\(errorInfo)") }
            return out.booleanValue ? .jumped : .fellBack
        }
    }

    static func script(uuid: String) -> String {
        // Returns true if a matching session was found and selected.
        """
        tell application "iTerm2"
            activate
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    repeat with aSession in sessions of aTab
                        if (id of aSession) is "\(uuid)" then
                            select aWindow
                            select aTab
                            select aSession
                            return true
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        return false
        """
    }
}
