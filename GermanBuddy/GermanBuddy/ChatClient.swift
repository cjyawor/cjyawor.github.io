import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String        // "user" or "assistant"
    var german: String      // what is spoken / heard
    var tip: String? = nil  // short English note, never spoken
}

struct ChatClient {
    // Fast and cheap model for live conversation. Swap for a bigger one if you want richer replies.
    static let model = "claude-haiku-5-5"

    static func systemPrompt(name: String, level: String, tips: Bool) -> String {
        """
        You are \(name), a warm, relaxed young woman who chats with a German learner.
        Speak standard German (Hochdeutsch) and always use the casual "du", never "Sie". Sound like a friend, not a textbook.

        About the learner: an adult in their 50s who spent a school year in Germany as a teenage exchange student and was fluent then. The German is rusty now. Understanding comes back faster than speaking, so be patient and encouraging. Starting level is about CEFR \(level). If they handle it easily, raise the difficulty a little at a time.

        Topics: adult life, work, family, travel, food, current events, and memories of the exchange year. Ask about their life and follow their lead.

        Replies: 1-3 short sentences, then a question that keeps them talking. Never use emojis, markdown, or lists. Your reply is read aloud.

        If the learner drops in an English word or says they cannot think of a word, work the German word naturally into your reply so they hear it in context.

        \(tips
          ? "After your German reply, add a line containing only --- and then one short English tip. Correct at most one mistake, the one that matters most, or teach one useful word or phrase. Skip the tip when there is nothing worth saying. Never list several corrections."
          : "Do not add English.")
        """
    }

    /// Streams raw text deltas as Claude writes them.
    static func stream(history: [ChatMessage], apiKey: String,
                       name: String, level: String, tips: Bool) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                do {
                    var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                    req.httpMethod = "POST"
                    req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    req.setValue("application/json", forHTTPHeaderField: "content-type")
                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 400,
                        "stream": true,
                        "system": systemPrompt(name: name, level: level, tips: tips),
                        "messages": history.map { ["role": $0.role, "content": $0.german] }
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        var data = Data()
                        for try await b in bytes { data.append(b) }
                        throw NSError(domain: "Claude", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                                      userInfo: [NSLocalizedDescriptionKey:
                                                    String(data: data, encoding: .utf8) ?? "Unknown error"])
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        guard let d = String(line.dropFirst(6)).data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                              json["type"] as? String == "content_block_delta",
                              let delta = json["delta"] as? [String: Any],
                              let text = delta["text"] as? String else { continue }
                        cont.yield(text)
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }
}
