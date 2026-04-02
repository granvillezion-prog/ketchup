import Foundation

public struct CircleSeedMember: Codable, Equatable {
    public let memberId: String
    public let displayName: String
    public let onKetchUp: Bool
    public let uid: String?
    public let username: String?
    public let phoneE164: String?

    public init(
        memberId: String,
        displayName: String,
        onKetchUp: Bool = false,
        uid: String? = nil,
        username: String? = nil,
        phoneE164: String? = nil
    ) {
        self.memberId = memberId
        self.displayName = displayName
        self.onKetchUp = onKetchUp
        self.uid = uid
        self.username = username
        self.phoneE164 = phoneE164
    }
}
