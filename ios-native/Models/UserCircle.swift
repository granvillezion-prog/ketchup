import Foundation

public struct UserCircle: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let index: Int

    public init(
        id: String,
        name: String,
        index: Int
    ) {
        self.id = id
        self.name = name
        self.index = index
    }
}
