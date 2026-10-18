import Foundation
import Testing
@testable import AashAI

@Suite struct GeminiProviderTests {
    private enum Fixture {
        static func data(_ name: String, file: StaticString = #filePath) throws -> Data {
            let url = URL(fileURLWithPath: "\(file)")
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/gemini")
                .appendingPathComponent(name)
            return try Data(contentsOf: url)
        }
    }

    private let hello = [ChatMessage(role: .user, text: "Hi")]

    private func provider(_ stub: StubURLProtocol.Stub, key: String? = "test-key") -> (GeminiProvider, String) {
        let (session, url) = StubURLProtocol.session(for: stub)
        return (GeminiProvider(apiKey: key, session: session, baseURL: url), url.host ?? "")
    }

    private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
        var chunks: [String] = []
        for try await chunk in stream { chunks.append(chunk) }
        return chunks
    }

    private func delta(_ text: String) -> String {
        "event: step.delta\ndata: {\"index\":0,\"delta\":{\"type\":\"text\",\"text\":\"\(text)\"},\"event_type\":\"step.delta\"}\n\n"
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ zone: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h)) ?? .distantPast
    }

    @Test func streamYieldsTextChunksInOrder() async throws {
        let body = delta("Hel") + delta("lo") + "event: done\ndata: [DONE]\n\n"
        let (gemini, _) = provider(.init(chunks: [Data(body.utf8)]))
        #expect(try await collect(gemini.stream(hello, system: "s")) == ["Hel", "lo"])
    }

    @Test func streamIgnoresNonTextEvents() async throws {
        let body = "event: interaction.created\ndata: {\"event_type\":\"interaction.created\"}\n\n"
            + "event: step.start\ndata: {\"index\":0,\"event_type\":\"step.start\"}\n\n"
            + delta("Hi")
            + "event: step.stop\ndata: {\"index\":0,\"event_type\":\"step.stop\"}\n\n"
            + "event: interaction.completed\ndata: {\"event_type\":\"interaction.completed\"}\n\n"
        let (gemini, _) = provider(.init(chunks: [Data(body.utf8)]))
        #expect(try await collect(gemini.stream(hello, system: "s")) == ["Hi"])
    }

    @Test func streamFixtureYieldsTheRecordedText() async throws {
        let (gemini, _) = provider(.init(chunks: [try Fixture.data("stream.txt")]))
        let chunks = try await collect(gemini.stream(hello, system: "s"))
        #expect(chunks.joined() == "Pixelated hello to you all!")
    }

    @Test func replyFixtureYieldsTheRecordedText() throws {
        let text = try GeminiWire.replyText(Fixture.data("reply.json"))
        #expect(text == "*Beep!* Hello there, friend!")
    }

    @Test func jsonFixtureReturnsParsableJSON() async throws {
        let (gemini, _) = provider(.init(chunks: [try Fixture.data("json-reply.json")]))
        let data = try await gemini.json("Remind me", system: "s", schema: Data("{\"type\":\"object\"}".utf8))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["isReminder"] as? Bool == true)
    }

    @Test func badKeyFixtureMapsToBadKey() async throws {
        let (gemini, _) = provider(.init(status: 400, chunks: [try Fixture.data("bad-key.json")]))
        await #expect(throws: ChatError.badKey) {
            _ = try await collect(gemini.stream(hello, system: "s"))
        }
    }

    @Test func status429MapsToQuotaWithPacificMidnight() {
        let first = GeminiWire.error(status: 429, body: Data(), now: date(2026, 10, 18, 10, "Asia/Kolkata"))
        #expect(first == .quota(resetsAt: date(2026, 10, 18, 7, "UTC")))
        let second = GeminiWire.error(status: 429, body: Data(), now: date(2026, 11, 2, 12, "UTC"))
        #expect(second == .quota(resetsAt: date(2026, 11, 3, 8, "UTC")))
    }

    @Test func status500MapsToServer() {
        let error = GeminiWire.error(status: 500, body: Data("{\"error\":{\"message\":\"boom\"}}".utf8),
                                     now: date(2026, 10, 18, 10, "UTC"))
        #expect(error == .server(status: 500, message: "boom"))
    }

    @Test func noKeyFailsWithoutARequest() async throws {
        for key in [nil, ""] as [String?] {
            let (gemini, host) = provider(.init(), key: key)
            await #expect(throws: ChatError.noKey) {
                _ = try await collect(gemini.stream(hello, system: "s"))
            }
            await #expect(throws: ChatError.noKey) {
                _ = try await gemini.json("p", system: "s", schema: Data("{}".utf8))
            }
            #expect(StubURLProtocol.requests(for: host).isEmpty)
        }
    }

    @Test func offlineAndTimeoutMapToChatErrors() async throws {
        let (offline, _) = provider(.init(error: URLError(.notConnectedToInternet)))
        await #expect(throws: ChatError.offline) {
            _ = try await collect(offline.stream(hello, system: "s"))
        }
        let (slow, _) = provider(.init(error: URLError(.timedOut)))
        await #expect(throws: ChatError.timedOut) {
            _ = try await collect(slow.stream(hello, system: "s"))
        }
    }

    @Test func requestCarriesKeyAndStoreFalse() async throws {
        let (gemini, host) = provider(.init(chunks: [Data(delta("x").utf8)]))
        _ = try await collect(gemini.stream(hello, system: "be brief"))
        let request = try #require(StubURLProtocol.requests(for: host).first)
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "test-key")
        #expect(request.httpMethod == "POST")
        #expect(request.url?.query == "alt=sse")
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["store"] as? Bool == false)
        #expect(json["stream"] as? Bool == true)
        #expect(json["system_instruction"] as? String == "be brief")
        let config = try #require(json["generation_config"] as? [String: Any])
        #expect(config["thinking_level"] as? String == "minimal")
        #expect(config["max_output_tokens"] as? Int == 1024)
    }

    @Test func twoTurnBodyMatchesTheFixtureShape() throws {
        let messages = [ChatMessage(role: .user, text: "My name is Sam."),
                        ChatMessage(role: .model, text: "Nice to meet you, Sam!"),
                        ChatMessage(role: .user, text: "What is my name?")]
        let body = try GeminiWire.body(model: "m", messages: messages, system: "s", stream: false, schema: nil)
        let mine = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        // two-turns.json holds the response; the request `input` it answered is recorded in the fixtures README.
        let recorded = """
        [{"type":"user_input","content":[{"type":"text","text":"My name is Sam."}]},\
        {"type":"model_output","content":[{"type":"text","text":"Nice to meet you, Sam!"}]},\
        {"type":"user_input","content":[{"type":"text","text":"What is my name?"}]}]
        """
        let left = try #require(mine["input"] as? NSArray)
        let right = try #require(try JSONSerialization.jsonObject(with: Data(recorded.utf8)) as? NSArray)
        #expect(left == right)
    }

    @Test func jsonRequestAddsResponseFormat() throws {
        let body = try GeminiWire.body(model: "m", messages: [ChatMessage(role: .user, text: "p")], system: "s",
                                       stream: false, schema: Data("{\"type\":\"object\"}".utf8))
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let format = try #require(json["response_format"] as? [String: Any])
        #expect(format["mime_type"] as? String == "application/json")
        #expect(json["stream"] == nil)
    }

    @Test func cancellingTheStreamCancelsTheRequest() async throws {
        let (gemini, host) = provider(.init(chunks: [Data(delta("a").utf8)], hold: true))
        let (signal, fire) = AsyncStream<Void>.makeStream()
        let reader = Task {
            for try await _ in gemini.stream(hello, system: "s") { fire.yield() }
        }
        for await _ in signal { break }
        reader.cancel()
        for _ in 0..<40 where !StubURLProtocol.stopped(for: host) {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(StubURLProtocol.stopped(for: host))
    }
}
