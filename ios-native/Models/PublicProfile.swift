import Foundation

public struct PublicProfile: Codable, Equatable {
    public let uid: String
    public let displayName: String
    public let username: String
    public let phoneE164: String
    public let photoUrl: String?

    public init(
        uid: String,
        displayName: String,
        username: String,
        phoneE164: String,
        photoUrl: String? = nil
    ) {
        self.uid = uid
        self.displayName = displayName
        self.username = username
        self.phoneE164 = phoneE164
        self.photoUrl = photoUrl
    }
}
