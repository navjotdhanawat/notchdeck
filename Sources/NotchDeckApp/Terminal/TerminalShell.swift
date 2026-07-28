import Foundation
import AppKit

/// Small helpers for CLI-driven terminal jumpers: resolve a binary, run it with a
/// timeout, and raise an app. Keeps WezTerm/Kitty adapters focused on their command.
enum TerminalShell {
    /// GUI apps get a minimal PATH, so construct a comprehensive search path containing
    /// common install locations for homebrew, npm, yarn, volta, pnpm, fnm, and asdf.
    static func searchPaths() -> [String] {
        let home = NSHomeDirectory()
        var dirs = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
            "\(home)/Library/pnpm",
            "\(home)/.local/share/pnpm",
            "\(home)/.yarn/bin",
            "\(home)/.volta/bin",
            "\(home)/.fnm/bin",
            "\(home)/.local/share/fnm/shims",
            "\(home)/.local/share/fnm/aliases/default/bin",
            "\(home)/.asdf/shims",
            "\(home)/.asdf/installs/nodejs/bin",
            "/usr/bin",
            "/bin"
        ]

        let nvmNodeDir = URL(fileURLWithPath: "\(home)/.nvm/versions/node")
        if let contents = try? FileManager.default.contentsOfDirectory(at: nvmNodeDir, includingPropertiesForKeys: nil) {
            for subDir in contents {
                dirs.append(subDir.appendingPathComponent("bin").path)
            }
        }

        if let envPath = ProcessInfo.processInfo.environment["PATH"] {
            dirs.append(contentsOf: envPath.split(separator: ":").map(String.init))
        }

        return dirs
    }

    static func resolve(_ name: String) -> String? {
        for d in searchPaths() {
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
