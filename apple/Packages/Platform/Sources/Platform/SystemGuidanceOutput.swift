import Foundation
import AVFoundation
import Domain
#if canImport(UIKit)
import UIKit
#endif

/// Bips + vibrations sur iPhone. Les bips se mélangent à la musique de l'athlète (`.mixWithOthers`).
/// Règles reprises de l'app Expo : alerte forte à 10 s, bip long à chaque fin de bloc / de séance.
@MainActor
public final class SystemGuidanceOutput: GuidanceOutput {
    private var shortBeep: AVAudioPlayer?
    private var longBeep: AVAudioPlayer?

    public init() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
        shortBeep = try? AVAudioPlayer(data: SineWAV.data(frequency: 880, durationMs: 180))
        longBeep = try? AVAudioPlayer(data: SineWAV.data(frequency: 880, durationMs: 540))
        shortBeep?.prepareToPlay()
        longBeep?.prepareToPlay()
    }

    public func play(_ cue: GuidanceCue) {
        switch cue {
        case .countdownTick:
            impact(.medium)
        case .go:
            beep(shortBeep)
            notify(.success)
        case .tenSecondsWarning:
            beep(shortBeep)
            strongWarningHaptics()
        case .blockEnd, .sessionEnd:
            beep(longBeep)
            notify(.success)
        case .stepDone:
            impact(.medium)
        case .setDone:
            beep(shortBeep)
            notify(.success)
        }
    }

    private func beep(_ player: AVAudioPlayer?) {
        player?.currentTime = 0
        player?.play()
    }

    // MARK: - Haptics (UIKit uniquement : absent sur macOS, donc ignoré pendant `swift test`)

    #if canImport(UIKit)
    private enum Impact { case medium, heavy }
    private enum Notification { case success, error }

    private func impact(_ style: Impact) {
        let generator = UIImpactFeedbackGenerator(style: style == .heavy ? .heavy : .medium)
        generator.impactOccurred()
    }

    private func notify(_ type: Notification) {
        UINotificationFeedbackGenerator().notificationOccurred(type == .error ? .error : .success)
    }

    /// Alerte forte : une notification « erreur » puis 8 impacts lourds rapprochés.
    private func strongWarningHaptics() {
        notify(.error)
        Task { @MainActor in
            for _ in 0..<8 {
                impact(.heavy)
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }
    #else
    private enum Impact { case medium, heavy }
    private enum Notification { case success, error }
    private func impact(_ style: Impact) {}
    private func notify(_ type: Notification) {}
    private func strongWarningHaptics() {}
    #endif
}
