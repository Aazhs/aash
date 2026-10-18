import Foundation

/// Request building, response decoding and error mapping for the Interactions API.
enum GeminiWire {
    /// The request body for a chat turn. `schema` non-nil adds `response_format`.
    static func body(model: String, messages: [ChatMessage], system: String, stream: Bool, schema: Data?) throws -> Data {
        let input: [[String: Any]] = messages.map { message in
            let type = message.role == .user ? "user_input" : "model_output"
            return ["type": type, "content": [["type": "text", "text": message.text]]]
        }
        var object: [String: Any] = [
            "model": model,
            "input": input,
            "system_instruction": system,
            "store": false,
            "generation_config": ["thinking_level": "minimal", "max_output_tokens": 1024] as [String: Any],
        ]
        if stream { object["stream"] = true }
        if let schema {
            guard let parsed = try? JSONSerialization.jsonObject(with: schema) else {
                throw ChatError.badResponse("bad schema")
            }
            object["response_format"] = ["type": "text", "mime_type": "application/json", "schema": parsed] as [String: Any]
        }
        do {
            return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        } catch {
            throw ChatError.badResponse("bad request")
        }
    }

    /// The reply text in a non-streamed response (all `model_output` text parts, joined).
    static func replyText(_ data: Data) throws -> String {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let steps = root["steps"] as? [[String: Any]] else {
            throw ChatError.badResponse("no text in reply")
        }
        var parts: [String] = []
        for step in steps where step["type"] as? String == "model_output" {
            let content = step["content"] as? [[String: Any]] ?? []
            for item in content where item["type"] as? String == "text" {
                if let text = item["text"] as? String { parts.append(text) }
            }
        }
        guard !parts.isEmpty else { throw ChatError.badResponse("no text in reply") }
        return parts.joined()
    }

    /// The text chunk in one SSE `data:` payload; nil for events without text; throws on an `error` event.
    static func chunk(_ event: ServerSentEvent) throws -> String? {
        if event.data == "[DONE]" { return nil }
        guard let root = (try? JSONSerialization.jsonObject(with: Data(event.data.utf8))) as? [String: Any] else {
            return nil
        }
        switch root["event_type"] as? String {
        case "step.delta":
            guard let delta = root["delta"] as? [String: Any], delta["type"] as? String == "text" else { return nil }
            return delta["text"] as? String
        case "error":
            let message = (root["error"] as? [String: Any])?["message"] as? String
            throw ChatError.server(status: 0, message: message ?? "stream error")
        default:
            return nil
        }
    }

    /// Maps a failed HTTP response to a `ChatError`.
    static func error(status: Int, body: Data, now: Date) -> ChatError {
        let text = String(decoding: body, as: UTF8.self)
        switch status {
        case 429:
            return .quota(resetsAt: nextPacificMidnight(after: now))
        case 401, 403:
            return .badKey
        case 400 where ["API key not valid", "API_KEY_INVALID", "PERMISSION_DENIED"].contains(where: text.contains):
            return .badKey
        case 408:
            return .timedOut
        default:
            if let message = errorMessage(body) { return .server(status: status, message: message) }
            let head = String(text.prefix(200))
            return .server(status: status, message: head.isEmpty ? "HTTP \(status)" : head)
        }
    }

    /// Midnight Pacific after `now`: when the free tier's daily limit resets.
    static func nextPacificMidnight(after now: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        if let zone = TimeZone(identifier: "America/Los_Angeles") { calendar.timeZone = zone }
        return calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                                 matchingPolicy: .nextTime) ?? now.addingTimeInterval(86400)
    }

    /// `error.message` from an error body; the body may be an object or an array holding one.
    private static func errorMessage(_ body: Data) -> String? {
        let parsed = try? JSONSerialization.jsonObject(with: body)
        let object = (parsed as? [String: Any]) ?? (parsed as? [[String: Any]])?.first
        return (object?["error"] as? [String: Any])?["message"] as? String
    }
}
