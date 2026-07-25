import Foundation
import AppKit
import NotchDeckCore

/// Best-effort: raise the terminal app by its name. No precise pane targeting.
public struct FallbackActivator: TerminalJumping {
    public init() {}
    public let adapterID = "generic"

    public func jump(to identity: TerminalIdentity) async -> JumpResult {
        let appName = identity.appName?.replacingOccurrences(of: ".app", with: "")
        return await MainActor.run {
            let apps = NSWorkspace.shared.runningApplications
            if let name = appName,
               let app = apps.first(where: { $0.localizedName == name || $0.bundleIdentifier?.contains(name.lowercased()) == true }) {
                app.activate(options: [.activateAllWindows])
                return .fellBack
            }
            return .failed("terminal app not found")
        }
    }
}
