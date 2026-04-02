import Foundation
import FirebaseAuth
import FirebaseFirestore

public final class ProgressService {
    private let db: Firestore
    private let auth: Auth

    public init(
        firestore: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth()
    ) {
        self.db = firestore
        self.auth = auth
    }

    public static func dateKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = String(format: "%04d", components.year ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)
        return "\(year)-\(month)-\(day)"
    }

    public func ensureUserDoc() async throws {
        let reference = try userDoc()
        let snapshot = try await reference.getDocument()
        let nowMs = Self.nowMs()

        let base: [String: Any] = [
            "points": 0,
            "currentStreak": 0,
            "longestStreak": 0,
            "lastCallAtMs": NSNull(),
            "lastCompletedCallAtMs": NSNull(),
            "lastActiveAtMs": nowMs,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        if !snapshot.exists {
            try await reference.setData(base, merge: true)
            return
        }

        let data = snapshot.data() ?? [:]
        var payload: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        if data["points"] == nil {
            payload["points"] = 0
        }
        if data["currentStreak"] == nil {
            payload["currentStreak"] = 0
        }
        if data["longestStreak"] == nil {
            payload["longestStreak"] = 0
        }
        if data["lastCallAtMs"] == nil {
            payload["lastCallAtMs"] = NSNull()
        }
        if data["lastCompletedCallAtMs"] == nil {
            payload["lastCompletedCallAtMs"] = NSNull()
        }
        if data["lastActiveAtMs"] == nil {
            payload["lastActiveAtMs"] = nowMs
        }

        try await reference.setData(payload, merge: true)
    }

    public func getUserProgress() async throws -> [String: Any] {
        let snapshot = try await userDoc().getDocument()
        return snapshot.data() ?? [:]
    }

    public func setUserProgress(_ data: [String: Any]) async throws {
        var payload = data
        payload["updatedAt"] = FieldValue.serverTimestamp()
        try await userDoc().setData(payload, merge: true)
    }

    public func touchActiveNow() async throws {
        try await userDoc().setData(
            [
                "lastActiveAtMs": Self.nowMs(),
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            merge: true
        )
    }

    public func markCallCompletedNow() async throws {
        let nowMs = Self.nowMs()
        try await userDoc().setData(
            [
                "lastActiveAtMs": nowMs,
                "lastCallAtMs": nowMs,
                "lastCompletedCallAtMs": nowMs,
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            merge: true
        )
    }

    public func isRecentlyActive(maxInactiveDays: Int = 3) async throws -> Bool {
        guard let lastActiveAtMs = try await getLastActiveAtMs() else {
            return false
        }

        let cutoffMs = maxInactiveDays * 24 * 60 * 60 * 1000
        return (Self.nowMs() - lastActiveAtMs) <= cutoffMs
    }

    public func getDay(_ dateKey: String) async throws -> [String: Any]? {
        let snapshot = try await daysCollection().document(dateKey).getDocument()
        guard snapshot.exists else {
            return nil
        }
        return snapshot.data()
    }

    public func wasDayMissed(_ dateKey: String) async throws -> Bool {
        guard let day = try await getDay(dateKey) else {
            return false
        }

        let hiddenName = ((day["hiddenName"] ?? "") as AnyObject)
            .description?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let completed = (day["callCompleted"] as? Bool) == true

        if hiddenName.isEmpty {
            return false
        }
        if hiddenName == "Add more friends" {
            return false
        }
        if completed {
            return false
        }

        return true
    }

    public func wasYesterdayMissed() async throws -> Bool {
        try await wasDayMissed(Self.yesterdayKey())
    }

    public func setDay(_ dateKey: String, data: [String: Any]) async throws {
        var merged = data
        merged["dateKey"] = dateKey
        merged["updatedAt"] = FieldValue.serverTimestamp()
        try await daysCollection().document(dateKey).setData(merged, merge: true)
    }

    private func uidOrThrow() throws -> String {
        guard let uid = auth.currentUser?.uid else {
            throw ProgressServiceError.noUserSignedIn
        }
        return uid
    }

    private func userDoc() throws -> DocumentReference {
        db.collection("users").document(try uidOrThrow())
    }

    private func daysCollection() throws -> CollectionReference {
        try userDoc().collection("days")
    }

    private func getLastActiveAtMs() async throws -> Int? {
        let data = try await getUserProgress()
        return Self.asInt(data["lastActiveAtMs"])
    }

    private func getLastCompletedCallAtMs() async throws -> Int? {
        let data = try await getUserProgress()
        return Self.asInt(data["lastCompletedCallAtMs"])
    }

    private static func todayKey() -> String {
        dateKey(for: Date())
    }

    private static func yesterdayKey() -> String {
        dateKey(for: Date().addingTimeInterval(-86_400))
    }

    private static func nowMs() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }

    private static func asInt(_ raw: Any?) -> Int? {
        if let value = raw as? Int {
            return value
        }
        if let value = raw as? NSNumber {
            return value.intValue
        }
        return nil
    }
}

public enum ProgressServiceError: Error {
    case noUserSignedIn
}