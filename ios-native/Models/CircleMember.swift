import Foundation

public struct CircleMember: Codable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let onKetchUp: Bool
    public let uid: String?
    public let username: String?
    public let phoneE164: String?

    public init(
        id: String,
        displayName: String,
        onKetchUp: Bool,
        uid: String? = nil,
        username: String? = nil,
        phoneE164: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.onKetchUp = onKetchUp
        self.uid = uid
        self.username = username
        self.phoneE164 = phoneE164
    }
}
