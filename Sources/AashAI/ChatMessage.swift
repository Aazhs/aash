/// One message in a conversation.
public struct ChatMessage: Equatable, Sendable {
    /// Who wrote the message.
    public enum Role: String, Sendable { case user, model }
    /// The author of the message.
    public var role: Role
    /// The message text.
    public var text: String

    /// Creates a message.
    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}
