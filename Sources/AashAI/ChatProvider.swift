import Foundation

/// Something that can answer a conversation.
public protocol ChatProvider: Sendable {
    /// Streams the reply as text chunks. Cancelling the stream cancels the request.
    func stream(_ messages: [ChatMessage], system: String) -> AsyncThrowingStream<String, Error>
    /// One non-streamed reply whose text is JSON matching `schema` (a JSON Schema document).
    func json(_ prompt: String, system: String, schema: Data) async throws -> Data
}

/// What can go wrong, in terms the UI can explain.
public enum ChatError: Error, Equatable, Sendable {
    /// No API key is stored.
    case noKey
    /// The API rejected the key.
    case badKey
    /// The quota is used up; `resetsAt` is when it refills, if known.
    case quota(resetsAt: Date?)
    /// There is no network connection.
    case offline
    /// The request took too long.
    case timedOut
    /// The server answered with an error status.
    case server(status: Int, message: String)
    /// The reply could not be understood.
    case badResponse(String)
}
