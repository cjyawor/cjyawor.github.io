import Foundation
import AVFoundation

/// Speaks German out loud. `wordTick` bumps on every spoken word so the avatar can move its mouth.
@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var wordTick = 0

    var rate: Float = 0.45
    private let synth = AVSpeechSynthesizer()
    private var pending = 0
    var onIdle: (() -> Void)?

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Queues one sentence. Safe to call repeatedly while a reply is still streaming in.
    func enqueue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pending += 1
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Speaker.bestGermanVoice()
        utterance.rate = rate
        utterance.pitchMultiplier = 1.05
        synth.speak(utterance)
    }

    /// Picks the best installed de-DE voice, preferring female, then Premium, then Enhanced.
    static func bestGermanVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "de-DE" }
        func score(_ v: AVSpeechSynthesisVoice) -> Int {
            var n = 0
            switch v.quality {
            case .premium: n += 20
            case .enhanced: n += 10
            default: break
            }
            if #available(iOS 17.0, *), v.gender == .female { n += 5 }
            return n
        }
        return voices.max { score($0) < score($1) } ?? AVSpeechSynthesisVoice(language: "de-DE")
    }

    var isBusy: Bool { pending > 0 }

    func stop() {
        pending = 0
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString r: NSRange,
                                       utterance u: AVSpeechUtterance) {
        Task { @MainActor in self.wordTick += 1 }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in
            self.pending = max(0, self.pending - 1)
            if self.pending == 0 {
                self.isSpeaking = false
                self.onIdle?()
            }
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in
            self.pending = max(0, self.pending - 1)
            if self.pending == 0 { self.isSpeaking = false }
        }
    }
}
