import Foundation

/// Serves canned responses so tests never touch the network. Stubs are keyed by host, so each test
/// uses its own host and parallel tests don't collide.
// @unchecked Sendable: URLProtocol is a non-Sendable class; all shared state is behind `lock`.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        var status: Int = 200
        var chunks: [Data] = []
        var hold = false
        var error: URLError?
    }

    // @unchecked Sendable: every access to the dictionaries goes through `lock`.
    private final class Box: @unchecked Sendable {
        let lock = NSLock()
        var stubs: [String: Stub] = [:]
        var recorded: [String: [URLRequest]] = [:]
        var stoppedHosts: Set<String> = []
    }

    private static let box = Box()

    /// Registers `stub` under a fresh host; returns a session wired to it and the base URL to use.
    static func session(for stub: Stub) -> (URLSession, URL) {
        let host = "stub-\(UUID().uuidString.lowercased()).test"
        box.lock.lock()
        box.stubs[host] = stub
        box.lock.unlock()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let url = URL(string: "https://\(host)/v1beta/interactions") ?? URL(fileURLWithPath: "/")
        return (URLSession(configuration: configuration), url)
    }

    /// The requests the stub for `host` has received, bodies included.
    static func requests(for host: String) -> [URLRequest] {
        box.lock.lock()
        defer { box.lock.unlock() }
        return box.recorded[host] ?? []
    }

    /// True once loading for `host` was stopped (the request was cancelled).
    static func stopped(for host: String) -> Bool {
        box.lock.lock()
        defer { box.lock.unlock() }
        return box.stoppedHosts.contains(host)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host else { return }
        var seen = request
        if let stream = request.httpBodyStream {
            seen.httpBody = Self.readAll(stream)
        }
        Self.box.lock.lock()
        let stub = Self.box.stubs[host] ?? Stub()
        Self.box.recorded[host, default: []].append(seen)
        Self.box.lock.unlock()

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "text/event-stream"])
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        for chunk in stub.chunks { client?.urlProtocol(self, didLoad: chunk) }
        if !stub.hold { client?.urlProtocolDidFinishLoading(self) }
    }

    override func stopLoading() {
        guard let host = request.url?.host else { return }
        Self.box.lock.lock()
        Self.box.stoppedHosts.insert(host)
        Self.box.lock.unlock()
    }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
