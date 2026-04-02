import Foundation

public struct MockQuestion: Codable, Equatable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }

    public var json: [String: Any] {
        [
            "id": id,
            "text": text,
        ]
    }

    public init?(json: [String: Any]) {
        guard let id = json["id"] as? String,
              let text = json["text"] as? String else {
            return nil
        }
        self.id = id
        self.text = text
    }
}

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

    public func copy(
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
        MockPair(
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

    public func toJson() -> [String: Any] {
        var payload: [String: Any] = [
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
            "circleId": circleId,
            "circleName": circleName,
            "callIndex": callIndex,
            "totalCalls": totalCalls,
        ]

        payload["lastCallAtMs"] = lastCallAtMs as Any
        payload["partnerUid"] = partnerUid as Any
        payload["partnerUsername"] = partnerUsername as Any
        return payload
    }

    public init?(json: [String: Any]) {
        guard let dateKey = json["dateKey"] as? String,
              let hiddenName = json["hiddenName"] as? String,
              let questionId = json["questionId"] as? String else {
            return nil
        }

        self.dateKey = dateKey
        self.hiddenName = hiddenName
        self.phone = json["phone"] as? String ?? ""
        self.questionId = questionId
        self.answerText = json["answerText"] as? String ?? ""
        self.myAnswerText = json["myAnswerText"] as? String ?? ""
        self.questionText = json["questionText"] as? String ?? ""
        self.callCompleted = json["callCompleted"] as? Bool ?? false
        self.points = json["points"] as? Int ?? (json["points"] as? String).flatMap(Int.init) ?? 0
        self.currentStreak = json["currentStreak"] as? Int ?? (json["currentStreak"] as? String).flatMap(Int.init) ?? 0
        self.longestStreak = json["longestStreak"] as? Int ?? (json["longestStreak"] as? String).flatMap(Int.init) ?? 0
        self.lastCallAtMs = json["lastCallAtMs"] as? Int ?? (json["lastCallAtMs"] as? String).flatMap(Int.init)
        self.circleId = json["circleId"] as? String ?? ""
        self.circleName = json["circleName"] as? String ?? ""
        self.callIndex = json["callIndex"] as? Int ?? (json["callIndex"] as? String).flatMap(Int.init) ?? 1
        self.totalCalls = json["totalCalls"] as? Int ?? (json["totalCalls"] as? String).flatMap(Int.init) ?? 1
        self.partnerUid = (json["partnerUid"] as? String)?.isEmpty == true ? nil : json["partnerUid"] as? String
        self.partnerUsername = (json["partnerUsername"] as? String)?.isEmpty == true ? nil : json["partnerUsername"] as? String
    }
}

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

    public init(id: String, data: [String: Any]) {
        self.id = id
        self.displayName = data["displayName"] as? String ?? ""
        self.onKetchUp = data["onKetchUp"] as? Bool ?? false
        self.uid = (data["uid"] as? String)?.isEmpty == true ? nil : data["uid"] as? String
        self.username = (data["username"] as? String)?.isEmpty == true ? nil : data["username"] as? String
        self.phoneE164 = (data["phoneE164"] as? String)?.isEmpty == true ? nil : data["phoneE164"] as? String
    }
}

public struct DailyEligibility: Codable, Equatable {
    public let userId: String
    public let eligibleFriendUids: [String]
    public let degree: Int
    public let isNewUser: Bool
    public let isPriorityTomorrow: Bool

    public init(
        userId: String,
        eligibleFriendUids: [String],
        degree: Int,
        isNewUser: Bool = false,
        isPriorityTomorrow: Bool = false
    ) {
        self.userId = userId
        self.eligibleFriendUids = eligibleFriendUids
        self.degree = degree
        self.isNewUser = isNewUser
        self.isPriorityTomorrow = isPriorityTomorrow
    }
}

public struct DailyAssignment: Codable, Equatable {
    public let userId: String
    public let pairedUserId: String?
    public let state: String
    public let assignedAt: Date

    public init(
        userId: String,
        pairedUserId: String? = nil,
        state: String,
        assignedAt: Date
    ) {
        self.userId = userId
        self.pairedUserId = pairedUserId
        self.state = state
        self.assignedAt = assignedAt
    }

    public func toJson() -> [String: Any] {
        [
            "userId": userId,
            "pairedUserId": pairedUserId as Any,
            "state": state,
            "assignedAt": Int(assignedAt.timeIntervalSince1970 * 1000),
        ]
    }
}

public struct PairHistoryEntry: Codable, Equatable {
    public let userA: String
    public let userB: String
    public let pairedAt: Date

    public init(userA: String, userB: String, pairedAt: Date) {
        self.userA = userA
        self.userB = userB
        self.pairedAt = pairedAt
    }
}
