import Foundation
import NotchDeckCore

/// Focuses a WezTerm pane via `wezterm cli activate-pane --pane-id <handle>`, then raises
/// the app so its window comes forward. Degrades to `.failed` (→ registry app-raise) when
/// the CLI is absent or the command fails.
public struct WezTermJumper: TerminalJumping {
    public init() {}
    public let adapterID = "wezterm"

    public func jump(to identity: TerminalIdentity) async -> JumpResult {
        guard let pane = identity.handle, !pane.isEmpty else { return .failed("no wezterm pane") }
        guard let bin = TerminalShell.resolve("wezterm") else { return .failed("wezterm not found") }
        let ok = await Task.detached {
            TerminalShell.run(bin, ["cli", "activate-pane", "--pane-id", pane], timeout: 2.0)
        }.value
        guard ok else { return .failed("wezterm activate-pane failed") }
        _ = await TerminalShell.raiseApp(named: identity.appName ?? "WezTerm")
        return .jumped
    }
}
