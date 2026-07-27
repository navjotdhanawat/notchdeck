import AppKit
import Foundation
import Sparkle

/// Manages automatic background software updates and manual update checks using Sparkle.
@MainActor
public final class UpdateManager: NSObject, SPUUpdaterDelegate {
    public static let shared = UpdateManager()

    private(set) var updaterController: SPUStandardUpdaterController!

    private override init() {
        super.init()
        // Initialize Sparkle standard updater controller
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    /// Trigger a manual update check UI modal.
    public func checkForUpdates(_ sender: Any? = nil) {
        updaterController.checkForUpdates(sender)
    }

    /// Whether an update check can currently be initiated.
    public var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    /// Provide feed URL with cache-busting timestamp to prevent stale CDN cache issues.
    public func feedURLString(for updater: SPUUpdater) -> String? {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "https://raw.githubusercontent.com/navjotdhanawat/notchdeck/main/appcast.xml?t=\(timestamp)"
    }
}
