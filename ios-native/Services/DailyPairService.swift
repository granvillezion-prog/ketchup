import Foundation
import FirebaseAuth
import FirebaseFirestore

public protocol DailyPairStorage {
    func getStoredTodayKey() -> String?
    func setStoredTodayKey(_ key: String) async throws

    func getTodayPair() -> MockPair?
    func setTodayPair(_ pair: MockPair) async throws
    func clearTodayPair() async throws

    func getCallStartedAt() -> Int?
    func setCallStartedAt(_ ms: Int) async throws

    func getCallTotalSeconds() -> Int?
    func setCallTotalSeconds(_ seconds: Int) async throws

    func getHasExtendedOnce() -> Bool
    func setHasExtendedOnce(_ value: Bool) async throws

    func clearCallTimer() async throws
    func clearDailyCallState() async throws

    func getProfileUsername() -> String
}

public struct DailyPairSnapshot: Equatable {
    public let pair: MockPair?
    public let availability: DailyPairAvailability
    public let effectiveDateKey: String
    public let resolvedQuestion: DailyPairQuestion
    public let answerState: DailyPairAnswerState
    public let callRecord: DailyPairCallRecord
    public let missedYesterday: Bool

    public init(
        pair: MockPair?,
        availability: DailyPairAvailability,
        effectiveDateKey: String,
        resolvedQuestion: DailyPairQuestion,
        answerState: DailyPairAnswerState,
        callRecord: DailyPairCallRecord,
        missedYesterday: Bool
    ) {
        self.pair = pair
        self.availability = availability
        self.effectiveDateKey = effectiveDateKey
        self.resolvedQuestion = resolvedQuestion
        self.answerState = answerState
        self.callRecord = callRecord
        self.missedYesterday = missedYesterday
    }
}

public enum DailyPairAvailability: Equatable {
    case setupRequired
    case unmatched
    case ready
    case completed
}

public struct DailyPairQuestion: Equatable {
    public let questionId: String
    public let questionText: String
    public let isFallback: Bool

    public init(questionId: String, questionText: String, isFallback: Bool) {
        self.questionId = questionId
        self.questionText = questionText
        self.isFallback = isFallback
    }
}

public struct DailyPairAnswerState: Equatable {
    public let incomingAnswerText: String
    public let myAnswerText: String
    public let hasSubmittedAnswer: Bool
    public let canSubmitAnswer: Bool

    public init(
        incomingAnswerText: String,
        myAnswerText: String,
        hasSubmittedAnswer: Bool,
        canSubmitAnswer: Bool
    ) {
        self.incomingAnswerText = incomingAnswerText
        self.myAnswerText = myAnswerText
        self.hasSubmittedAnswer = hasSubmittedAnswer
        self.canSubmitAnswer = canSubmitAnswer
    }
}

public struct DailyPairCallRecord: Equatable {
    public let startedAtMs: Int?
    public let totalSeconds: Int?
    public let hasExtendedOnce: Bool
    public let callCompleted: Bool
    public let lastCallAtMs: Int?

    public init(
        startedAtMs: Int?,
        totalSeconds: Int?,
        hasExtendedOnce: Bool,
        callCompleted: Bool,
        lastCallAtMs: Int?
    ) {
        self.startedAtMs = startedAtMs
        self.totalSeconds = totalSeconds
        self.hasExtendedOnce = hasExtendedOnce
        self.callCompleted = callCompleted
        self.lastCallAtMs = lastCallAtMs
    }
}

public struct DailyPairMutationResult: Equatable {
    public let snapshot: DailyPairSnapshot
    public let didChange: Bool

    public init(snapshot: DailyPairSnapshot, didChange: Bool) {
        self.snapshot = snapshot
        self.didChange = didChange
    }
}

public struct DailyPairPollingResult: Equatable {
    public let snapshot: DailyPairSnapshot
    public let didReceiveNewAnswer: Bool

    public init(snapshot: DailyPairSnapshot, didReceiveNewAnswer: Bool) {
        self.snapshot = snapshot
        self.didReceiveNewAnswer = didReceiveNewAnswer
    }
}

public enum DailyPairServiceError: Error {
    case noAuthenticatedUser
}

public final class DailyPairService {
    private static let questions: [MockQuestion] = [
        MockQuestion(id: "q1", text: "What’s something that made you laugh recently?"),
        MockQuestion(id: "q2", text: "What’s your favorite meal ever?"),
        MockQuestion(id: "q3", text: "What’s one habit you’re trying to build?"),
        MockQuestion(id: "q4", text: "What’s a memory you keep replaying lately?"),
        MockQuestion(id: "q0", text: "Add more people to unlock your daily call"),
    ]

    private static let answerCollectionName = "daily_answers"

    private let db: Firestore
    private let auth: Auth
    private let firestoreService: FirestoreService
    private let progressService: ProgressService
    private let storage: DailyPairStorage

    public init(
        firestore: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth(),
        firestoreService: FirestoreService,
        progressService: ProgressService,
        storage: DailyPairStorage
    ) {
        self.db = firestore
        self.auth = auth
        self.firestoreService = firestoreService
        self.progressService = progressService
        self.storage = storage
    }

    public func loadTodayPair() async throws -> DailyPairSnapshot {
        let key = effectiveDateKeyNowOrCallStart()
        try await resetIfNewKey(key)

        if let cached = storage.getTodayPair(), cached.dateKey == key {
            if storage.getCallStartedAt() != nil || !cached.callCompleted {
                return try await buildSnapshot(from: cached, effectiveDateKey: key)
            }
        }

        let uid = try currentUserIdOrThrow()
        try await progressService.ensureUserDoc()

        let assignmentSnapshot = try await dailyUserDocument(key: key, uid: uid).getDocument()
        let dayMap = try await progressService.getDay(key)
        let cached = storage.getTodayPair()

        if let pair = try await bestAvailablePair(
            key: key,
            assignmentSnapshot: assignmentSnapshot,
            dayMap: dayMap,
            cached: cached
        ) {
            try await storage.setTodayPair(pair)
            return try await buildSnapshot(from: pair, effectiveDateKey: key)
        }

        try await joinDailyPool(key: key, uid: uid)

        let reassignedSnapshot = try await dailyUserDocument(key: key, uid: uid).getDocument()
        if let pair = try await bestAvailablePair(
            key: key,
            assignmentSnapshot: reassignedSnapshot,
            dayMap: dayMap,
            cached: cached
        ) {
            try await storage.setTodayPair(pair)
            return try await buildSnapshot(from: pair, effectiveDateKey: key)
        }

        let unmatchedPair = try await buildNoFriendsPair(key: key)
        try await persistSingleAssignment(
            key: key,
            currentUid: uid,
            pair: unmatchedPair,
            state: "unmatched_priority_tomorrow",
            allowLateJoin: false
        )
        try await storage.setTodayPair(unmatchedPair)
        return try await buildSnapshot(from: unmatchedPair, effectiveDateKey: key)
    }

    public func refresh() async throws -> DailyPairSnapshot {
        try await loadTodayPair()
    }

    public func submitAnswer(_ rawText: String) async throws -> DailyPairMutationResult {
        let snapshot = try await loadTodayPair()
        guard let pair = snapshot.pair else {
            return DailyPairMutationResult(snapshot: snapshot, didChange: false)
        }

        let text = sanitizeAnswer(rawText)
        guard !text.isEmpty else {
            return DailyPairMutationResult(snapshot: snapshot, didChange: false)
        }

        let myUsername = storage.getProfileUsername().trimmingCharacters(in: .whitespacesAndNewlines)
        let recipientUsername = pair.hiddenName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !myUsername.isEmpty, !recipientUsername.isEmpty else {
            return DailyPairMutationResult(snapshot: snapshot, didChange: false)
        }

        let updatedPair = pair.copyWith(myAnswerText: text)
        try await storage.setTodayPair(updatedPair)

        let answerId = "\(pair.dateKey)__\(recipientUsername)__\(Int.random(in: 0..<(1 << 30)))"
        try await answersCollection.document(answerId).setData(
            [
                "dateKey": pair.dateKey,
                "recipient": recipientUsername,
                "answerText": text,
                "createdAt": FieldValue.serverTimestamp(),
            ]
        )

        let existingDay = try await progressService.getDay(pair.dateKey) ?? [:]
        var updatedDay = existingDay
        updatedDay["hiddenName"] = updatedPair.hiddenName
        updatedDay["phone"] = updatedPair.phone
        updatedDay["questionId"] = updatedPair.questionId
        updatedDay["questionText"] = updatedPair.questionText
        updatedDay["answerText"] = updatedPair.answerText
        updatedDay["myAnswerText"] = updatedPair.myAnswerText
        updatedDay["callCompleted"] = updatedPair.callCompleted
        updatedDay["circleId"] = updatedPair.circleId
        updatedDay["circleName"] = updatedPair.circleName
        updatedDay["callIndex"] = updatedPair.callIndex
        updatedDay["totalCalls"] = updatedPair.totalCalls
        updatedDay["partnerUid"] = updatedPair.partnerUid as Any
        updatedDay["partnerUsername"] = updatedPair.partnerUsername as Any
        try await progressService.setDay(pair.dateKey, data: updatedDay)

        let updatedSnapshot = try await buildSnapshot(from: updatedPair, effectiveDateKey: pair.dateKey)
        return DailyPairMutationResult(snapshot: updatedSnapshot, didChange: true)
    }

    public func markCallStarted(
        startedAtMs: Int,
        totalSeconds: Int
    ) async throws -> DailyPairMutationResult {
        let snapshot = try await loadTodayPair()
        try await storage.setCallStartedAt(startedAtMs)
        try await storage.setCallTotalSeconds(totalSeconds)
        try await storage.setHasExtendedOnce(false)

        let updatedSnapshot = try await buildSnapshot(
            from: snapshot.pair,
            effectiveDateKey: snapshot.effectiveDateKey
        )
        return DailyPairMutationResult(snapshot: updatedSnapshot, didChange: true)
    }

    public func markCallExtendedOnce(
        totalSeconds: Int
    ) async throws -> DailyPairMutationResult {
        let snapshot = try await loadTodayPair()
        try await storage.setCallTotalSeconds(totalSeconds)
        try await storage.setHasExtendedOnce(true)

        let updatedSnapshot = try await buildSnapshot(
            from: snapshot.pair,
            effectiveDateKey: snapshot.effectiveDateKey
        )
        return DailyPairMutationResult(snapshot: updatedSnapshot, didChange: true)
    }

    public func markCallComplete(
        completedAtMs: Int
    ) async throws -> DailyPairMutationResult {
        let snapshot = try await loadTodayPair()
        guard let pair = snapshot.pair else {
            return DailyPairMutationResult(snapshot: snapshot, didChange: false)
        }

        try await enforceStreakLossIfNeeded(referenceDateKey: pair.dateKey)

        if pair.callCompleted {
            try await clearCallSession()
            let unchangedSnapshot = try await buildSnapshot(from: pair, effectiveDateKey: pair.dateKey)
            return DailyPairMutationResult(snapshot: unchangedSnapshot, didChange: false)
        }

        let progress = try await progressService.getUserProgress()
        let oldPoints = intOrDefault(progress["points"], default: pair.points)
        let oldCurrentStreak = intOrDefault(progress["currentStreak"], default: pair.currentStreak)
        let oldLongestStreak = intOrDefault(progress["longestStreak"], default: pair.longestStreak)
        let lastCompletedMs = nullableInt(progress["lastCompletedCallAtMs"])

        let todayKey = pair.dateKey
        let yesterdayKey = Self.dateKey(from: Date(timeIntervalSince1970: TimeInterval(completedAtMs - 86_400_000) / 1000))
        let completedToday = lastCompletedMs.map { Self.dateKey(fromMs: $0) == todayKey } ?? false

        let nextPoints: Int
        let nextCurrentStreak: Int
        let nextLongestStreak: Int

        if completedToday {
            nextPoints = oldPoints
            nextCurrentStreak = oldCurrentStreak
            nextLongestStreak = oldLongestStreak
        } else {
            let completedYesterday = lastCompletedMs.map { Self.dateKey(fromMs: $0) == yesterdayKey } ?? false
            nextPoints = oldPoints + 1
            nextCurrentStreak = completedYesterday ? oldCurrentStreak + 1 : 1
            nextLongestStreak = max(oldLongestStreak, nextCurrentStreak)
        }

        let updatedPair = pair.copyWith(
            callCompleted: true,
            lastCallAtMs: .some(completedAtMs),
            points: nextPoints,
            currentStreak: nextCurrentStreak,
            longestStreak: nextLongestStreak
        )

        try await storage.setTodayPair(updatedPair)
        try await progressService.markCallCompletedNow()
        try await progressService.setUserProgress(
            [
                "points": nextPoints,
                "currentStreak": nextCurrentStreak,
                "longestStreak": nextLongestStreak,
                "lastCallAtMs": completedAtMs,
                "lastCompletedCallAtMs": completedAtMs,
                "lastActiveAtMs": completedAtMs,
            ]
        )

        let existingDay = try await progressService.getDay(todayKey) ?? [:]
        var updatedDay = existingDay
        updatedDay["hiddenName"] = updatedPair.hiddenName
        updatedDay["phone"] = updatedPair.phone
        updatedDay["questionId"] = updatedPair.questionId
        updatedDay["questionText"] = updatedPair.questionText
        updatedDay["answerText"] = updatedPair.answerText
        updatedDay["myAnswerText"] = updatedPair.myAnswerText
        updatedDay["callCompleted"] = true
        updatedDay["completedAtMs"] = completedAtMs
        updatedDay["lastCallAtMs"] = completedAtMs
        updatedDay["points"] = nextPoints
        updatedDay["currentStreak"] = nextCurrentStreak
        updatedDay["longestStreak"] = nextLongestStreak
        updatedDay["circleId"] = updatedPair.circleId
        updatedDay["circleName"] = updatedPair.circleName
        updatedDay["callIndex"] = updatedPair.callIndex
        updatedDay["totalCalls"] = updatedPair.totalCalls
        updatedDay["partnerUid"] = updatedPair.partnerUid as Any
        updatedDay["partnerUsername"] = updatedPair.partnerUsername as Any
        try await progressService.setDay(todayKey, data: updatedDay)

        let uid = try currentUserIdOrThrow()
        try await mirrorCompletionStateToAssignment(
            key: todayKey,
            uid: uid,
            pair: updatedPair,
            completedAtMs: completedAtMs
        )

        try await clearCallSession()
        let updatedSnapshot = try await buildSnapshot(from: updatedPair, effectiveDateKey: todayKey)
        return DailyPairMutationResult(snapshot: updatedSnapshot, didChange: true)
    }

    public func handlePolling() async throws -> DailyPairPollingResult {
        let snapshot = try await loadTodayPair()
        guard let pair = snapshot.pair else {
            return DailyPairPollingResult(snapshot: snapshot, didReceiveNewAnswer: false)
        }

        let myUsername = storage.getProfileUsername().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !myUsername.isEmpty else {
            return DailyPairPollingResult(snapshot: snapshot, didReceiveNewAnswer: false)
        }

        let querySnapshot = try await answersCollection
            .whereField("dateKey", isEqualTo: pair.dateKey)
            .whereField("recipient", isEqualTo: myUsername)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let document = querySnapshot.documents.first else {
            return DailyPairPollingResult(snapshot: snapshot, didReceiveNewAnswer: false)
        }

        let incomingText = strictStringOrEmpty(document.data()["answerText"])
        guard !incomingText.isEmpty, incomingText != pair.answerText else {
            return DailyPairPollingResult(snapshot: snapshot, didReceiveNewAnswer: false)
        }

        let updatedPair = pair.copyWith(answerText: incomingText)
        try await storage.setTodayPair(updatedPair)
        let updatedSnapshot = try await buildSnapshot(from: updatedPair, effectiveDateKey: pair.dateKey)
        return DailyPairPollingResult(snapshot: updatedSnapshot, didReceiveNewAnswer: true)
    }

    public func clearCallSession() async throws {
        try await storage.clearCallTimer()
        try await storage.setHasExtendedOnce(false)
    }

    private var answersCollection: CollectionReference {
        db.collection(Self.answerCollectionName)
    }

    private func dailyUsersCollection(key: String) -> CollectionReference {
        db.collection("daily_assignments").document(key).collection("users")
    }

    private func dailyUserDocument(key: String, uid: String) -> DocumentReference {
        dailyUsersCollection(key: key).document(uid)
    }

    private func dailyPoolCollection(key: String) -> CollectionReference {
        db.collection("daily_pool").document(key).collection("users")
    }

    private func currentUserIdOrThrow() throws -> String {
        guard let uid = auth.currentUser?.uid else {
            throw DailyPairServiceError.noAuthenticatedUser
        }
        return uid
    }

    private func effectiveDateKeyNowOrCallStart() -> String {
        if let startedAt = storage.getCallStartedAt() {
            return Self.dateKey(fromMs: startedAt)
        }
        return Self.dateKey(from: Date())
    }

    private func resetIfNewKey(_ key: String) async throws {
        let storedKey = storage.getStoredTodayKey()
        guard storedKey != key else {
            return
        }

        try await storage.setStoredTodayKey(key)
        try await storage.clearDailyCallState()
        try await storage.clearCallTimer()
        try await storage.setHasExtendedOnce(false)
        try await storage.clearTodayPair()
    }

    private func buildSnapshot(from pair: MockPair?, effectiveDateKey: String) async throws -> DailyPairSnapshot {
        let missedYesterday = try await progressService.wasYesterdayMissed()
        let resolvedQuestion = resolveQuestion(for: pair)
        let answerState = buildAnswerState(from: pair)
        let callRecord = DailyPairCallRecord(
            startedAtMs: storage.getCallStartedAt(),
            totalSeconds: storage.getCallTotalSeconds(),
            hasExtendedOnce: storage.getHasExtendedOnce(),
            callCompleted: pair?.callCompleted ?? false,
            lastCallAtMs: pair?.lastCallAtMs
        )

        return DailyPairSnapshot(
            pair: pair,
            availability: availability(for: pair),
            effectiveDateKey: effectiveDateKey,
            resolvedQuestion: resolvedQuestion,
            answerState: answerState,
            callRecord: callRecord,
            missedYesterday: missedYesterday
        )
    }

    private func availability(for pair: MockPair?) -> DailyPairAvailability {
        guard let pair else {
            return .setupRequired
        }

        if pair.hiddenName == "Add more friends" {
            return .unmatched
        }
        if pair.callCompleted {
            return .completed
        }
        return .ready
    }

    private func resolveQuestion(for pair: MockPair?) -> DailyPairQuestion {
        guard let pair else {
            return DailyPairQuestion(questionId: "", questionText: "", isFallback: true)
        }

        if !pair.questionText.isEmpty {
            return DailyPairQuestion(
                questionId: pair.questionId,
                questionText: pair.questionText,
                isFallback: false
            )
        }

        let fallback = Self.questions.first(where: { $0.id == pair.questionId }) ?? Self.questions[0]
        return DailyPairQuestion(
            questionId: pair.questionId.isEmpty ? fallback.id : pair.questionId,
            questionText: fallback.text,
            isFallback: true
        )
    }

    private func buildAnswerState(from pair: MockPair?) -> DailyPairAnswerState {
        let incoming = pair?.answerText ?? ""
        let mine = pair?.myAnswerText ?? ""
        let canSubmit = {
            guard let pair else {
                return false
            }
            return !pair.callCompleted && pair.hiddenName != "Add more friends"
        }()

        return DailyPairAnswerState(
            incomingAnswerText: incoming,
            myAnswerText: mine,
            hasSubmittedAnswer: !mine.isEmpty,
            canSubmitAnswer: canSubmit
        )
    }

    private func bestAvailablePair(
        key: String,
        assignmentSnapshot: DocumentSnapshot,
        dayMap: [String: Any]?,
        cached: MockPair?
    ) async throws -> MockPair? {
        let assignmentPair: MockPair? = if assignmentSnapshot.exists {
            try await mapPairFromAssignmentData(key: key, data: assignmentSnapshot.data() as? [String: Any] ?? [:])
        } else {
            nil
        }

        let dayPair: MockPair? = if let dayMap {
            try await mapPairFromDayData(key: key, data: dayMap)
        } else {
            nil
        }

        return reconcilePreferredPair(
            key: key,
            assignmentPair: assignmentPair,
            dayPair: dayPair,
            cachedPair: cached
        )
    }

    private func reconcilePreferredPair(
        key: String,
        assignmentPair: MockPair?,
        dayPair: MockPair?,
        cachedPair: MockPair?
    ) -> MockPair? {
        let sameDayCached = cachedPair?.dateKey == key ? cachedPair : nil

        if let dayPair, dayPair.callCompleted {
            return mergePair(dayPair, withCached: sameDayCached)
        }
        if let sameDayCached, sameDayCached.callCompleted {
            return sameDayCached
        }
        if let assignmentPair, !assignmentPair.callCompleted {
            return mergePair(assignmentPair, withCached: sameDayCached)
        }
        if let dayPair {
            return mergePair(dayPair, withCached: sameDayCached)
        }
        if let assignmentPair {
            return mergePair(assignmentPair, withCached: sameDayCached)
        }
        return sameDayCached
    }

    private func mergePair(_ pair: MockPair, withCached cached: MockPair?) -> MockPair {
        guard let cached, cached.dateKey == pair.dateKey else {
            return pair
        }

        return pair.copyWith(
            answerText: pair.answerText.isEmpty ? cached.answerText : pair.answerText,
            myAnswerText: pair.myAnswerText.isEmpty ? cached.myAnswerText : pair.myAnswerText,
            questionText: pair.questionText.isEmpty ? cached.questionText : pair.questionText,
            partnerUid: pair.partnerUid == nil ? .some(cached.partnerUid) : .some(pair.partnerUid),
            partnerUsername: pair.partnerUsername == nil ? .some(cached.partnerUsername) : .some(pair.partnerUsername)
        )
    }

    private func joinDailyPool(key: String, uid: String) async throws {
        try await dailyPoolCollection(key: key).document(uid).setData(
            [
                "uid": uid,
                "joinedAt": FieldValue.serverTimestamp(),
            ],
            merge: true
        )
    }

    private func mapPairFromAssignmentData(key: String, data: [String: Any]) async throws -> MockPair {
        let progress = try await progressService.getUserProgress()
        let partnerUid = strictStringOrEmpty(data["partnerUid"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let partnerUsername = strictStringOrEmpty(data["partnerUsername"]).trimmingCharacters(in: .whitespacesAndNewlines)

        return MockPair(
            dateKey: key,
            hiddenName: stringOrDefault(data["hiddenName"], default: "Mysto"),
            phone: strictStringOrEmpty(data["phone"]),
            questionId: stringOrDefault(data["questionId"], default: "q0"),
            answerText: strictStringOrEmpty(data["answerText"]),
            myAnswerText: strictStringOrEmpty(data["myAnswerText"]),
            questionText: strictStringOrEmpty(data["questionText"]),
            callCompleted: boolOrDefault(data["callCompleted"], default: false),
            points: intOrDefault(progress["points"], default: 0),
            currentStreak: intOrDefault(progress["currentStreak"], default: 0),
            longestStreak: intOrDefault(progress["longestStreak"], default: 0),
            lastCallAtMs: nullableInt(progress["lastCallAtMs"]),
            circleId: strictStringOrEmpty(data["circleId"]),
            circleName: strictStringOrEmpty(data["circleName"]),
            callIndex: intOrDefault(data["callIndex"], default: 1),
            totalCalls: intOrDefault(data["totalCalls"], default: 1),
            partnerUid: partnerUid.isEmpty ? nil : partnerUid,
            partnerUsername: partnerUsername.isEmpty ? nil : partnerUsername
        )
    }

    private func mapPairFromDayData(key: String, data: [String: Any]) async throws -> MockPair {
        let progress = try await progressService.getUserProgress()
        let partnerUid = strictStringOrEmpty(data["partnerUid"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let partnerUsername = strictStringOrEmpty(data["partnerUsername"]).trimmingCharacters(in: .whitespacesAndNewlines)

        return MockPair(
            dateKey: key,
            hiddenName: stringOrDefault(data["hiddenName"], default: "Mysto"),
            phone: strictStringOrEmpty(data["phone"]),
            questionId: stringOrDefault(data["questionId"], default: "q0"),
            answerText: strictStringOrEmpty(data["answerText"]),
            myAnswerText: strictStringOrEmpty(data["myAnswerText"]),
            questionText: strictStringOrEmpty(data["questionText"]),
            callCompleted: boolOrDefault(data["callCompleted"], default: false),
            points: intOrDefault(progress["points"], default: 0),
            currentStreak: intOrDefault(progress["currentStreak"], default: 0),
            longestStreak: intOrDefault(progress["longestStreak"], default: 0),
            lastCallAtMs: nullableInt(progress["lastCallAtMs"]),
            circleId: strictStringOrEmpty(data["circleId"]),
            circleName: strictStringOrEmpty(data["circleName"]),
            callIndex: intOrDefault(data["callIndex"], default: 1),
            totalCalls: intOrDefault(data["totalCalls"], default: 1),
            partnerUid: partnerUid.isEmpty ? nil : partnerUid,
            partnerUsername: partnerUsername.isEmpty ? nil : partnerUsername
        )
    }

    private func persistSingleAssignment(
        key: String,
        currentUid: String,
        pair: MockPair,
        state: String,
        allowLateJoin: Bool
    ) async throws {
        try await dailyUserDocument(key: key, uid: currentUid).setData(
            [
                "userId": currentUid,
                "partnerUid": pair.partnerUid as Any,
                "partnerUsername": pair.partnerUsername as Any,
                "hiddenName": pair.hiddenName,
                "phone": pair.phone,
                "questionId": pair.questionId,
                "questionText": pair.questionText,
                "answerText": pair.answerText,
                "myAnswerText": pair.myAnswerText,
                "callCompleted": false,
                "state": state,
                "allowLateJoin": allowLateJoin,
                "circleId": pair.circleId,
                "circleName": pair.circleName,
                "callIndex": pair.callIndex,
                "totalCalls": pair.totalCalls,
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            merge: true
        )
    }

    private func mirrorCompletionStateToAssignment(
        key: String,
        uid: String,
        pair: MockPair,
        completedAtMs: Int
    ) async throws {
        try await dailyUserDocument(key: key, uid: uid).setData(
            [
                "answerText": pair.answerText,
                "myAnswerText": pair.myAnswerText,
                "callCompleted": true,
                "completedAtMs": completedAtMs,
                "lastCallAtMs": completedAtMs,
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            merge: true
        )
    }

    private func buildNoFriendsPair(key: String) async throws -> MockPair {
        let progress = try await progressService.getUserProgress()
        return MockPair(
            dateKey: key,
            hiddenName: "Add more friends",
            phone: "",
            questionId: "q0",
            answerText: "",
            myAnswerText: "",
            questionText: "Add more people to unlock your daily call",
            callCompleted: false,
            points: intOrDefault(progress["points"], default: 0),
            currentStreak: intOrDefault(progress["currentStreak"], default: 0),
            longestStreak: intOrDefault(progress["longestStreak"], default: 0),
            lastCallAtMs: nullableInt(progress["lastCallAtMs"]),
            circleId: "",
            circleName: "unmatched_priority_tomorrow",
            callIndex: 1,
            totalCalls: 1,
            partnerUid: nil,
            partnerUsername: nil
        )
    }

    private func enforceStreakLossIfNeeded(referenceDateKey: String) async throws {
        try await progressService.ensureUserDoc()
        let progress = try await progressService.getUserProgress()
        let lastCompletedMs = nullableInt(progress["lastCompletedCallAtMs"])
        guard let lastCompletedMs else {
            return
        }

        let lastCompletedKey = Self.dateKey(fromMs: lastCompletedMs)
        let yesterdayKey = Self.dateKey(from: Date(timeIntervalSince1970: TimeInterval(Self.nowMs() - 86_400_000) / 1000))

        if lastCompletedKey == referenceDateKey || lastCompletedKey == yesterdayKey {
            return
        }

        let currentStreak = intOrDefault(progress["currentStreak"], default: 0)
        guard currentStreak > 0 else {
            return
        }

        try await progressService.setUserProgress(["currentStreak": 0])
    }

    private func sanitizeAnswer(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        return trimmed.count > 140 ? String(trimmed.prefix(140)) : trimmed
    }

    private static func dateKey(from date: Date) -> String {
        ProgressService.dateKey(for: date)
    }

    private static func dateKey(fromMs ms: Int) -> String {
        dateKey(from: Date(timeIntervalSince1970: TimeInterval(ms) / 1000))
    }

    private static func nowMs() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }

    private func strictStringOrEmpty(_ raw: Any?) -> String {
        raw as? String ?? ""
    }

    private func stringOrDefault(_ raw: Any?, default defaultValue: String) -> String {
        raw as? String ?? defaultValue
    }

    private func boolOrDefault(_ raw: Any?, default defaultValue: Bool) -> Bool {
        raw as? Bool ?? defaultValue
    }

    private func intOrDefault(_ raw: Any?, default defaultValue: Int) -> Int {
        if let value = raw as? Int {
            return value
        }
        if let value = raw as? NSNumber {
            return value.intValue
        }
        if let value = raw as? String, let parsed = Int(value) {
            return parsed
        }
        return defaultValue
    }

    private func nullableInt(_ raw: Any?) -> Int? {
        if raw is NSNull || raw == nil {
            return nil
        }
        if let value = raw as? Int {
            return value
        }
        if let value = raw as? NSNumber {
            return value.intValue
        }
        if let value = raw as? String {
            return Int(value)
        }
        return nil
    }
}