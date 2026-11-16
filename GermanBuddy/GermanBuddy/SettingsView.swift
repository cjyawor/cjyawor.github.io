import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var convo: Conversation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Anthropic API key") {
                    SecureField("sk-ant-...", text: $convo.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Stored in the iOS Keychain on this phone only.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section("Avatar") {
                    TextField("Name", text: convo.$avatarName)
                }
                Section("German level") {
                    Picker("Level", selection: convo.$level) {
                        ForEach(["A1", "A2", "B1", "B2", "C1"], id: \.self) { Text($0) }
                    }.pickerStyle(.segmented)
                    Toggle("Show English tips", isOn: convo.$showTips)
                }
                Section("Voice speed") {
                    Slider(value: Binding(
                        get: { Double(convo.speaker.rate) },
                        set: { convo.speaker.rate = Float($0) }),
                        in: 0.3...0.55)
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
