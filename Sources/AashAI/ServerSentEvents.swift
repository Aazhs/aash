/// One server-sent event: the `event:` name (if the frame had one) and its `data:` payload.
public struct ServerSentEvent: Equatable, Sendable {
    /// The `event:` name, if any.
    public var name: String?
    /// The `data:` payload.
    public var data: String

    /// Creates an event.
    public init(name: String?, data: String) {
        self.name = name
        self.data = data
    }
}

/// Turns SSE lines into events. Feed it one line at a time.
public struct ServerSentEventParser: Sendable {
    private var pendingName: String?

    /// Creates an empty parser.
    public init() {}

    /// Returns the event completed by `line`, or nil.
    public mutating func feed(_ line: String) -> ServerSentEvent? {
        // Each data line is a whole event: `AsyncBytes.lines` drops blank lines.
        if line.hasPrefix("event:") {
            pendingName = String(line.dropFirst(6).drop(while: { $0 == " " }))
            return nil
        }
        if line.hasPrefix("data:") {
            var rest = line.dropFirst(5)
            if rest.first == " " { rest = rest.dropFirst() }
            let event = ServerSentEvent(name: pendingName, data: String(rest))
            pendingName = nil
            return event
        }
        return nil
    }
}
