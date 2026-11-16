import Foundation
import SwiftUI

enum Phase { case idle, listening, thinking, speaking }

@MainActor
final class Conversation: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var phase: Phase = .idle
    @Published var errorText: String?

    @AppStorage("level") var level = "B1"
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

    private var streamDone = true

    init() {
        speaker.onIdle = { [weak self] in
            guard let self, self.streamDone, self.phase == .speaking else { return }
            self.phase = .idle
        }
    }

    func send(_ text: String) async {
        guard !apiKey.isEmpty else {
            errorText = "Add your Anthropic API key in settings."
            phase = .idle
            return
        }
        messages.append(ChatMessage(role: "user", german: text))
        let history = messages
        messages.append(ChatMessage(role: "assistant", german: ""))
        let index = messages.count - 1
        phase = .thinking
        streamDone = false

        var full = ""
        var spoken = 0   // characters of the German part already sent to the speaker

        do {
            for try await delta in ChatClient.stream(history: history, apiKey: apiKey,
                                                     name: avatarName, level: level, tips: showTips) {
                full += delta
                let (german, tip, tipStarted) = Conversation.split(full)
                messages[index].german = german
                messages[index].tip = tip

                // speak every finished sentence as soon as it arrives
                let chars = Array(german)
                var cut = spoken
                var i = spoken
                while i < chars.count - 1 {
                    if ".!?".contains(chars[i]) && chars[i + 1].isWhitespace { cut = i + 1 }
                    i += 1
                }
                if tipStarted { cut = chars.count }
                if cut > spoken {
                    if phase == .thinking { phase = .speaking }
                    speaker.enqueue(String(chars[spoken..<cut]))
                    spoken = cut
                }
            }
            // flush whatever is left
            let (german, tip, _) = Conversation.split(full)
            messages[index].german = german
            messages[index].tip = tip
            let chars = Array(german)
            if spoken < chars.count {
                phase = .speaking
                speaker.enqueue(String(chars[spoken...]))
            }
            streamDone = true
            if !speaker.isBusy { phase = .idle }
        } catch {
            streamDone = true
            errorText = error.localizedDescription
            if messages[index].german.isEmpty { messages.remove(at: index) }
            if !speaker.isBusy { phase = .idle }
        }
    }

    /// Splits streamed text into the spoken German part and the English tip after "---".
    static func split(_ text: String) -> (german: String, tip: String?, tipStarted: Bool) {
        if let r = text.range(of: "\n---") {
            let g = String(text[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let t = String(text[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (g, t.isEmpty ? nil : t, true)
        }
        // hold back a half-arrived "\n--" so it is never spoken
        var g = text
        while let last = g.last, last == "-" || last == "\n" { g.removeLast() }
        return (g.trimmingCharacters(in: .whitespacesAndNewlines), nil, false)
    }

    func reset() {
        speaker.stop()
        messages = []
        phase = .idle
    }
}
