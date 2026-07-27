import AppKit
import NotchDeckCore
import AVFoundation

final class RetroSynth {
    static let shared = RetroSynth()

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    init() {
        setupEngine()
    }

    private func setupEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            self.audioEngine = engine
            self.playerNode = player
        } catch {
            print("RetroSynth: Failed to start audioEngine: \(error)")
        }
    }

    func playMelody(_ melody: [(Double, Double)], volume: Float = 0.15) {
        if audioEngine == nil || playerNode == nil {
            setupEngine()
        }
        guard let player = playerNode, let engine = audioEngine, engine.isRunning else { return }

        let sampleRate = 44100.0
        var totalSamples = 0
        for (_, duration) in melody {
            totalSamples += Int(duration * sampleRate)
        }

        guard totalSamples > 0 else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples)) else { return }
        buffer.frameLength = AVAudioFrameCount(totalSamples)

        guard let channelData = buffer.floatChannelData?[0] else { return }

        var sampleIndex = 0
        for (freq, duration) in melody {
            let noteSamples = Int(duration * sampleRate)
            for i in 0..<noteSamples {
                guard sampleIndex < totalSamples else { break }
                if freq == 0 {
                    channelData[sampleIndex] = 0.0
                } else {
                    let t = Double(i) / sampleRate
                    let wave = sin(2.0 * .pi * freq * t) >= 0.0 ? 1.0 : -1.0
                    channelData[sampleIndex] = Float(wave) * volume
                }
                sampleIndex += 1
            }
        }

        player.stop()
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
    }

    func playSweep(from startFreq: Double, to endFreq: Double, duration: Double, isNoise: Bool = false, volume: Float = 0.15) {
        if audioEngine == nil || playerNode == nil {
            setupEngine()
        }
        guard let player = playerNode, let engine = audioEngine, engine.isRunning else { return }

        let sampleRate = 44100.0
        let totalSamples = Int(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples)) else { return }
        buffer.frameLength = AVAudioFrameCount(totalSamples)

        guard let channelData = buffer.floatChannelData?[0] else { return }

        var phase = 0.0
        for i in 0..<totalSamples {
            let progress = Double(i) / Double(totalSamples)

            if isNoise {
                channelData[i] = Float.random(in: -1.0...1.0) * volume
            } else {
                let currentFreq = startFreq + (endFreq - startFreq) * progress
                phase += 2.0 * .pi * currentFreq / sampleRate
                let wave = sin(phase) >= 0.0 ? 1.0 : -1.0
                channelData[i] = Float(wave) * volume
            }
        }

        player.stop()
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
    }
}

public final class SoundPlayer {
    public var enabled: Bool
    public init(enabled: Bool = true) { self.enabled = enabled }

    public func play(_ effect: SessionEffect) {
        guard enabled else { return }

        // Read animation theme preference dynamically
        let savedTheme = UserDefaults.standard.string(forKey: "notch.animationTheme") ?? "lego"

        switch savedTheme {
        case "pacman":
            if effect == .soundDone {
                // Classic Major arpeggio sweep
                let melody: [(Double, Double)] = [
                    (523.25, 0.05), // C5
                    (659.25, 0.05), // E5
                    (783.99, 0.05), // G5
                    (1046.50, 0.15) // C6
                ]
                RetroSynth.shared.playMelody(melody, volume: 0.12)
            } else {
                // Pacman dying sound down sweep arpeggio
                var melody: [(Double, Double)] = []
                for scale in 0..<3 {
                    let base = 800.0 - Double(scale) * 150.0
                    for i in 0..<8 {
                        melody.append((base - Double(i) * 60.0, 0.025))
                    }
                    melody.append((0, 0.015))
                }
                RetroSynth.shared.playMelody(melody, volume: 0.12)
            }

        case "pokemon":
            if effect == .soundDone {
                // Pokéball click + Level-up arpeggio
                let melody: [(Double, Double)] = [
                    (880.0, 0.03), // Click sound
                    (0.0, 0.02),
                    (659.25, 0.06), // E5
                    (880.0, 0.06),  // A5
                    (1046.50, 0.06), // C6
                    (1174.66, 0.06), // D6
                    (1318.51, 0.06), // E6
                    (1567.98, 0.18)  // G6
                ]
                RetroSynth.shared.playMelody(melody, volume: 0.12)
            } else {
                // Fainting noise rattle
                RetroSynth.shared.playSweep(from: 350.0, to: 80.0, duration: 0.45, isNoise: false, volume: 0.15)
            }

        case "mario":
            if effect == .soundDone {
                // Mario Coin sound (B5 -> E6)
                let melody: [(Double, Double)] = [
                    (987.77, 0.07), // B5
                    (1318.51, 0.35) // E6
                ]
                RetroSynth.shared.playMelody(melody, volume: 0.12)
            } else {
                // Mario Dying arpeggio
                let melody: [(Double, Double)] = [
                    (1046.50, 0.08), // C6
                    (1174.66, 0.08), // D6
                    (1318.51, 0.08), // E6
                    (0.0, 0.05),
                    (987.77, 0.08),  // B5
                    (880.0, 0.08),   // A5
                    (783.99, 0.08),  // G5
                    (0.0, 0.05),
                    (523.25, 0.20)   // C5
                ]
                RetroSynth.shared.playMelody(melody, volume: 0.12)
            }

        case "space":
            if effect == .soundDone {
                // Laser beam shot
                RetroSynth.shared.playSweep(from: 100.0, to: 1200.0, duration: 0.22, isNoise: false, volume: 0.10)
            } else {
                // Space Invaders explosion
                RetroSynth.shared.playSweep(from: 200.0, to: 50.0, duration: 0.40, isNoise: true, volume: 0.14)
            }

        default:
            // Default Lego / Graphite sounds: Glass for success, Basso for failure
            let name: NSSound.Name = (effect == .soundFailed) ? "Basso" : "Glass"
            NSSound(named: name)?.play()
        }
    }

    /// A soft, distinct sound for a surfaced failure (e.g. a jump that couldn't land).
    public func playError() {
        guard enabled else { return }
        NSSound(named: "Funk")?.play()
    }
}
