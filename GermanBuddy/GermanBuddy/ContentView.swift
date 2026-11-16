import SwiftUI

struct ContentView: View {
    @EnvironmentObject var convo: Conversation
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            AvatarHost()
                .padding(.top, 8)
            Text(statusText)
                .font(.footnote).foregroundColor(.secondary)
                .padding(.vertical, 6)
            transcript
            if let e = convo.errorText {
                Text(e).font(.footnote).foregroundColor(.red).padding(.horizontal)
            }
            micButton
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear { if convo.apiKey.isEmpty { showSettings = true } }
    }

    private var header: some View {
        HStack {
            Text(convo.avatarName).font(.title2.bold())
            Spacer()
            Button { convo.reset() } label: { Image(systemName: "arrow.counterclockwise") }
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
        }
        .padding(.horizontal).padding(.top, 8)
    }

    private var statusText: String {
        switch convo.phase {
        case .idle: return "Tap the mic and speak German"
        case .listening: return convo.speech.transcript.isEmpty ? "Listening..." : convo.speech.transcript
        case .thinking: return "\(convo.avatarName) is thinking..."
        case .speaking: return "\(convo.avatarName) is speaking"
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(convo.messages) { m in
                        VStack(alignment: m.role == "user" ? .trailing : .leading, spacing: 2) {
                            Text(m.german)
                                .padding(10)
                                .background(m.role == "user" ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                                .cornerRadius(12)
                            if let tip = m.tip {
                                Text(tip).font(.caption).foregroundColor(.secondary).padding(.horizontal, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: m.role == "user" ? .trailing : .leading)
                        .id(m.id)
                    }
                }
                .padding()
            }
            .onChange(of: convo.messages) { m in
                if let last = m.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private var micButton: some View {
        Button {
            Task { await convo.toggleMic() }
        } label: {
            Image(systemName: convo.phase == .listening ? "stop.fill" : "mic.fill")
                .font(.system(size: 30))
                .foregroundColor(.white)
                .frame(width: 76, height: 76)
                .background(convo.phase == .listening ? Color.red : Color.blue)
                .clipShape(Circle())
        }
        .disabled(convo.phase == .thinking)
        .padding(.bottom, 20)
    }
}

/// Observes the speaker so the avatar redraws on every word.
private struct AvatarHost: View {
    @EnvironmentObject var convo: Conversation
    var body: some View { Inner(speaker: convo.speaker, phase: convo.phase) }

    struct Inner: View {
        @ObservedObject var speaker: Speaker
        let phase: Phase
        var body: some View { AvatarView(phase: phase, wordTick: speaker.wordTick) }
    }
}
