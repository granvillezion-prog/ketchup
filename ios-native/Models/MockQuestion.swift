import Foundation

public struct MockQuestion: Codable, Equatable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }

    public init(json: [String: Any]) {
        func stringValue(_ key: String) -> String {
            let value = json[key]
            if value is NSNull || value == nil { return "" }
            return String(describing: value!)
        }

        self.id = stringValue("id")
        self.text = stringValue("text")
    }

    public func toJson() -> [String: Any?] {
        [
            "id": id,
            "text": text,
        ]
    }
}
