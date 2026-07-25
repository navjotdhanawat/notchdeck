import AppKit
import ClaudeNotchCore

public final class SoundPlayer {
    public var enabled: Bool
    public init(enabled: Bool = true) { self.enabled = enabled }

    public func play(_ effect: SessionEffect) {
        guard enabled else { return }
        let name: NSSound.Name = (effect == .soundFailed) ? "Basso" : "Glass"
        NSSound(named: name)?.play()
    }

    /// A soft, distinct sound for a surfaced failure (e.g. a jump that couldn't land).
    public func playError() {
        guard enabled else { return }
        NSSound(named: "Funk")?.play()
    }
}
