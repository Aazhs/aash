import Foundation
import os

/// Chats with Gemini through the Interactions API.
public struct GeminiProvider: ChatProvider {
    private static let log = Logger(subsystem: "me.aarshj.aash", category: "Gemini")

    private let apiKey: String?
    private let model: String
    private let session: URLSession
    private let baseURL: URL
    private let now: @Sendable () -> Date

    /// `apiKey` nil or empty makes every call fail with `.noKey` before any request.
    /// `baseURL` and `now` exist for tests.
    public init(apiKey: String?, model: String = "gemini-3.5-flash-lite",
                session: URLSession = .shared,
                baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!, // constant literal
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.baseURL = baseURL
        self.now = now
    }

    /// Streams the reply as text chunks. Cancelling the stream cancels the request.
    public func stream(_ messages: [ChatMessage], system: String) -> AsyncThrowingStream<String, Error> {
        let apiKey = self.apiKey
        let model = self.model
        let session = self.session
        let baseURL = self.baseURL
        let now = self.now
        return AsyncThrowingStream { continuation in
            let task = Task {
                guard let apiKey, !apiKey.isEmpty else {
                    continuation.finish(throwing: ChatError.noKey)
                    return
                }
                do {
                    let body = try GeminiWire.body(model: model, messages: messages, system: system, stream: true, schema: nil)
                    let request = Self.request(url: baseURL, key: apiKey, body: body, sse: true)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw ChatError.badResponse("no response") }
                    guard (200..<300).contains(http.statusCode) else {
                        var errorBody = Data()
                        for try await byte in bytes {
                            errorBody.append(byte)
                            if errorBody.count >= 4096 { break }
                        }
                        bytes.task.cancel()
                        Self.log.error("Gemini HTTP status \(http.statusCode, privacy: .public)")
                        continuation.finish(throwing: GeminiWire.error(status: http.statusCode, body: errorBody, now: now()))
                        return
                    }
                    var parser = ServerSentEventParser()
                    // Cancelling the task alone doesn't wake a read that is waiting for the next line.
                    try await withTaskCancellationHandler {
                        for try await line in bytes.lines {
                            try Task.checkCancellation()
                            if let event = parser.feed(line), let text = try GeminiWire.chunk(event) {
                                continuation.yield(text)
                            }
                        }
                    } onCancel: {
                        bytes.task.cancel()
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// One non-streamed reply whose text is JSON matching `schema`.
    public func json(_ prompt: String, system: String, schema: Data) async throws -> Data {
        guard let apiKey, !apiKey.isEmpty else { throw ChatError.noKey }
        do {
            let body = try GeminiWire.body(model: model, messages: [ChatMessage(role: .user, text: prompt)],
                                           system: system, stream: false, schema: schema)
            let request = Self.request(url: baseURL, key: apiKey, body: body, sse: false)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ChatError.badResponse("no response") }
            guard (200..<300).contains(http.statusCode) else {
                Self.log.error("Gemini HTTP status \(http.statusCode, privacy: .public)")
                throw GeminiWire.error(status: http.statusCode, body: data, now: now())
            }
            return Data(try GeminiWire.replyText(data).utf8)
        } catch {
            throw Self.map(error)
        }
    }

    private static func request(url: URL, key: String, body: Data, sse: Bool) -> URLRequest {
        var target = url
        if sse, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "alt", value: "sse")]
            target = components.url ?? url
        }
        var request = URLRequest(url: target)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = body
        request.timeoutInterval = 30
        return request
    }

    private static func map(_ error: Error) -> ChatError {
        if let chat = error as? ChatError { return chat }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: return .offline
            case .timedOut: return .timedOut
            default: break
            }
        }
        return .badResponse(error.localizedDescription)
    }
}
