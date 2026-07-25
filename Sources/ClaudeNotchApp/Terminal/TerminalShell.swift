import Foundation
import AppKit

/// Small helpers for CLI-driven terminal jumpers: resolve a binary, run it with a
/// timeout, and raise an app. Keeps WezTerm/Kitty adapters focused on their command.
enum TerminalShell {
    /// GUI apps get a minimal PATH, so search common install dirs explicitly.
    static func resolve(_ name: String) -> String? {
        let dirs = ["/opt/homebrew/bin", "/usr/local/bin",
                    "\(NSHomeDirectory())/.local/bin", "/usr/bin", "/bin"]
        for d in dirs {
            let p = "\(d)/\(name)"
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    /// Run `launchPath args` (argv array — no shell). Returns true iff it exits 0 within `timeout`.
    static func run(_ launchPath: String, _ args: [String], timeout: TimeInterval) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        let sem = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in sem.signal() }
        do { try p.run() } catch { return false }
        if sem.wait(timeout: .now() + timeout) == .timedOut {
            p.terminate()
            return false
        }
        return p.terminationStatus == 0
    }

    /// Bring an app to the front by name. Returns true iff a matching app was found.
    @MainActor static func raiseApp(named appName: String?) -> Bool {
        guard let name = appName?.replacingOccurrences(of: ".app", with: "") else { return false }
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.localizedName == name || $0.bundleIdentifier?.contains(name.lowercased()) == true }) {
            app.activate(options: [.activateAllWindows])
            return true
        }
        return false
    }
}
