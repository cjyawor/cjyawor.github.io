import Foundation
import SwiftUI

enum Phase { case idle, listening, thinking, speaking }

@MainActor
final class Conversation: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var phase: Phase = .idle
    @Published var errorText: String?

    @AppStorage("level") var level = "A2"
    @AppStorage("showTips") var showTips = true
    @AppStorage("avatarName") var avatarName = "Lena"
    @Published var apiKey: String = Keychain.read("anthropic") {
        didSet { Keychain.write("anthropic", value: apiKey) }
    }

    let speech = SpeechRecognizer()
    let speaker = Speaker()

    func toggleMic() async {
        errorText = nil
        switch phase {
        case .listening:
            let heard = speech.stop()
            guard !heard.trimmingCharacters(in: .whitespaces).isEmpty else { phase = .idle; return }
            await send(heard)
        case .speaking:
            speaker.stop()
            phase = .idle
        case .idle:
            guard await speech.requestPermissions() else {
                errorText = "Allow microphone and speech recognition in Settings."
                return
            }
            do {
                try speech.start()
                phase = .listening
            } catch {
                errorText = error.localizedDescription
            }
        case .thinking:
            break
        }
    }

    func send(_ text: String) async {
        guard !apiKey.isEmpty else {
            errorText = "Add your Anthropic API key in settings."
            phase = .idle
            return
        }
        messages.append(ChatMessage(role: "user", german: text))
        phase = .thinking
        do {
            let r = try await ChatClient.reply(history: messages, apiKey: apiKey,
                                               name: avatarName, level: level, tips: showTips)
            messages.append(ChatMessage(role: "assistant", german: r.german, tip: r.tip))
            phase = .speaking
            speaker.speak(r.german) { [weak self] in self?.phase = .idle }
        } catch {
            errorText = error.localizedDescription
            phase = .idle
        }
    }

    func reset() {
        speaker.stop()
        messages = []
        phase = .idle
    }
}
