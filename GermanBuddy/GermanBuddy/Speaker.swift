import Foundation
import AVFoundation

/// Speaks German out loud. `wordTick` bumps on every spoken word so the avatar can move its mouth.
@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var wordTick = 0

    var rate: Float = 0.45
    private let synth = AVSpeechSynthesizer()
    private var onFinish: (() -> Void)?

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
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

    func stop() {
        synth.stopSpeaking(at: .immediate)
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
            self.isSpeaking = false
            self.onFinish?()
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
