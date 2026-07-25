import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)      // no Dock icon; never steals focus
// Top-level code runs on the main thread but is nonisolated under Swift 5 language
// mode, so hop onto the main actor to construct the @MainActor-isolated coordinator.
let delegate = MainActor.assumeIsolated { AppCoordinator() }
app.delegate = delegate
app.run()
