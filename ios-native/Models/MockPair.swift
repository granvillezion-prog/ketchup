import Foundation

public struct MockPair: Codable, Equatable {
    public let dateKey: String
    public let hiddenName: String
    public let phone: String
    public let questionId: String
    public let answerText: String
    public let myAnswerText: String
    public let questionText: String
    public let callCompleted: Bool
    public let points: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastCallAtMs: Int?
    public let circleId: String
    public let circleName: String
    public let callIndex: Int
    public let totalCalls: Int
    public let partnerUid: String?
    public let partnerUsername: String?

    public init(
        dateKey: String,
        hiddenName: String,
        phone: String = "",
        questionId: String,
        answerText: String = "",
        myAnswerText: String = "",
        questionText: String = "",
        callCompleted: Bool = false,
        points: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCallAtMs: Int? = nil,
        circleId: String = "",
        circleName: String = "",
        callIndex: Int = 1,
        totalCalls: Int = 1,
        partnerUid: String? = nil,
        partnerUsername: String? = nil
    ) {
        self.dateKey = dateKey
        self.hiddenName = hiddenName
        self.phone = phone
        self.questionId = questionId
        self.answerText = answerText
        self.myAnswerText = myAnswerText
        self.questionText = questionText
        self.callCompleted = callCompleted
        self.points = points
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCallAtMs = lastCallAtMs
        self.circleId = circleId
        self.circleName = circleName
        self.callIndex = callIndex
        self.totalCalls = totalCalls
        self.partnerUid = partnerUid
        self.partnerUsername = partnerUsername
    }

    public func copyWith(
        dateKey: String? = nil,
        hiddenName: String? = nil,
        phone: String? = nil,
        questionId: String? = nil,
        answerText: String? = nil,
        myAnswerText: String? = nil,
        questionText: String? = nil,
        callCompleted: Bool? = nil,
        points: Int? = nil,
        currentStreak: Int? = nil,
        longestStreak: Int? = nil,
        lastCallAtMs: Int?? = nil,
        circleId: String? = nil,
        circleName: String? = nil,
        callIndex: Int? = nil,
        totalCalls: Int? = nil,
        partnerUid: String?? = nil,
        partnerUsername: String?? = nil
    ) -> MockPair {
        return MockPair(
            dateKey: dateKey ?? self.dateKey,
            hiddenName: hiddenName ?? self.hiddenName,
            phone: phone ?? self.phone,
            questionId: questionId ?? self.questionId,
            answerText: answerText ?? self.answerText,
            myAnswerText: myAnswerText ?? self.myAnswerText,
            questionText: questionText ?? self.questionText,
            callCompleted: callCompleted ?? self.callCompleted,
            points: points ?? self.points,
            currentStreak: currentStreak ?? self.currentStreak,
            longestStreak: longestStreak ?? self.longestStreak,
            lastCallAtMs: lastCallAtMs ?? self.lastCallAtMs,
            circleId: circleId ?? self.circleId,
            circleName: circleName ?? self.circleName,
            callIndex: callIndex ?? self.callIndex,
            totalCalls: totalCalls ?? self.totalCalls,
            partnerUid: partnerUid ?? self.partnerUid,
            partnerUsername: partnerUsername ?? self.partnerUsername
        )
    }

    public init(json: [String: Any]) {
        func stringValue(_ key: String) -> String {
            let value = json[key]
            if value is NSNull || value == nil { return "" }
            return String(describing: value!)
        }

        func intValue(_ key: String, fallback: Int) -> Int {
            let value = json[key]
            if let intValue = value as? Int {
                return intValue
            }
            if let stringValue = value as? String, let parsed = Int(stringValue) {
                return parsed
            }
            return fallback
        }

        func boolValue(_ key: String, fallback: Bool) -> Bool {
            let value = json[key]
            if let boolValue = value as? Bool {
                return boolValue
            }
            if let stringValue = value as? String {
                let lowered = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if lowered == "true" { return true }
                if lowered == "false" { return false }
            }
            return fallback
        }

        func nullableIntValue(_ key: String) -> Int? {
            let value = json[key]
            if value is NSNull || value == nil { return nil }
            if let intValue = value as? Int {
                return intValue
            }
            if let stringValue = value as? String, let parsed = Int(stringValue) {
                return parsed
            }
            return nil
        }

        func optionalStringValue(_ key: String) -> String? {
            let value = json[key]
            if value is NSNull || value == nil { return nil }
            let str = String(describing: value!)
            return str.isEmpty ? nil : str
        }

        self.dateKey = stringValue("dateKey")
        self.hiddenName = stringValue("hiddenName")
        self.phone = stringValue("phone")
        self.questionId = stringValue("questionId")
        self.answerText = stringValue("answerText")
        self.myAnswerText = stringValue("myAnswerText")
        self.questionText = stringValue("questionText")
        self.callCompleted = boolValue("callCompleted", fallback: false)
        self.points = intValue("points", fallback: 0)
        self.currentStreak = intValue("currentStreak", fallback: 0)
        self.longestStreak = intValue("longestStreak", fallback: 0)
        self.lastCallAtMs = nullableIntValue("lastCallAtMs")
        self.circleId = stringValue("circleId")
        self.circleName = stringValue("circleName")
        self.callIndex = intValue("callIndex", fallback: 1)
        self.totalCalls = intValue("totalCalls", fallback: 1)
        self.partnerUid = optionalStringValue("partnerUid")
        self.partnerUsername = optionalStringValue("partnerUsername")
    }

    public func toJson() -> [String: Any?] {
        [
            "dateKey": dateKey,
            "hiddenName": hiddenName,
            "phone": phone,
            "questionId": questionId,
            "answerText": answerText,
            "myAnswerText": myAnswerText,
            "questionText": questionText,
            "callCompleted": callCompleted,
            "points": points,
            "currentStreak": currentStreak,
            "longestStreak": longestStreak,
            "lastCallAtMs": lastCallAtMs as Any,
            "circleId": circleId,
            "circleName": circleName,
            "callIndex": callIndex,
            "totalCalls": totalCalls,
            "partnerUid": partnerUid as Any,
            "partnerUsername": partnerUsername as Any,
        ]
    }
}
