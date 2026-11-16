import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String        // "user" or "assistant"
    let german: String      // what is spoken / heard
    var tip: String? = nil  // short English note, never spoken
}

struct ChatClient {
    // Fast and cheap model for live conversation. Swap for a bigger one if you want richer replies.
    static let model = "claude-haiku-5-5"

    static func systemPrompt(name: String, level: String, tips: Bool) -> String {
        """
        You are \(name), a warm, relaxed young woman who chats with a German learner at CEFR level \(level).
        Speak standard German (Hochdeutsch) and always use the casual "du", never "Sie". Sound like a friend, not a textbook.
        Keep replies to 1-3 short sentences at that level and end with a question that keeps the conversation going.
        Never use emojis, markdown, or lists. Your reply is read aloud.
        \(tips
          ? "After your German reply, add a line containing only --- and then one short English tip: correct any mistake the learner made, or give a useful word or phrase. Skip the tip if there is nothing worth saying."
          : "Do not add English.")
        """
    }

    static func reply(history: [ChatMessage], apiKey: String,
                      name: String, level: String, tips: Bool) async throws -> (german: String, tip: String?) {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 400,
            "system": systemPrompt(name: name, level: level, tips: tips),
            "messages": history.map { ["role": $0.role, "content": $0.german] }
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Claude", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw NSError(domain: "Claude", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Unexpected response."])
        }

        let parts = text.components(separatedBy: "\n---")
        let german = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let tip = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        return (german, (tip?.isEmpty ?? true) ? nil : tip)
    }
}
