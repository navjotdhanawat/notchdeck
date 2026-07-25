import Foundation
import NotchDeckCore

/// Focuses a Kitty window via `kitty @ focus-window --match id:<handle>`, then raises the app.
/// Requires Kitty remote control to be enabled; degrades to `.failed` (→ registry app-raise)
/// when the CLI is absent, remote control is off, or the command fails.
public struct KittyJumper: TerminalJumping {
    public init() {}
    public let adapterID = "kitty"

    public func jump(to identity: TerminalIdentity) async -> JumpResult {
        guard let win = identity.handle, !win.isEmpty else { return .failed("no kitty window id") }
        guard let bin = TerminalShell.resolve("kitty") else { return .failed("kitty not found") }
        let ok = await Task.detached {
            TerminalShell.run(bin, ["@", "focus-window", "--match", "id:\(win)"], timeout: 2.0)
        }.value
        guard ok else { return .failed("kitty focus-window failed") }
        _ = await TerminalShell.raiseApp(named: identity.appName ?? "kitty")
        return .jumped
    }
}
