import Foundation
import FirebaseFirestore

public final class FirestoreService {
    public static func normalizeUsername(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func normalizePhone(_ raw: String) -> String {
        let digits = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .filter(CharacterSet.decimalDigits.contains)
            .map(String.init)
            .joined()

        return digits.isEmpty ? "" : "+\(digits)"
    }

    public static func buildSearchTokens(displayName: String, username: String) -> [String] {
        let displayToken = cleanToken(displayName)
        let usernameToken = cleanToken(username)

        var base: [String] = []
        if !displayToken.isEmpty {
            base.append(displayToken)
        }
        if !usernameToken.isEmpty {
            base.append(usernameToken)
        }

        let words = displayToken
            .split(separator: " ")
            .map(String.init)
            + usernameToken.split(separator: " ").map(String.init)

        if !displayToken.isEmpty {
            base.append(displayToken.replacingOccurrences(of: " ", with: ""))
        }
        if !usernameToken.isEmpty {
            base.append(usernameToken.replacingOccurrences(of: " ", with: ""))
        }

        var tokenSet = Set<String>()

        func addWithPrefixes(_ word: String) {
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return
            }

            tokenSet.insert(trimmed)

            let maxPrefixLength = min(trimmed.count, 10)
            guard maxPrefixLength >= 2 else {
                return
            }

            for length in 2...maxPrefixLength {
                tokenSet.insert(String(trimmed.prefix(length)))
            }
        }

        for value in base {
            addWithPrefixes(value)
        }
        for value in words where !value.isEmpty {
            addWithPrefixes(value)
        }

        let sorted = tokenSet.sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs < rhs
            }
            return lhs.count < rhs.count
        }

        return Array(sorted.prefix(80))
    }

    private let uid: String
    private let db: Firestore

    public init(uid: String, firestore: Firestore = Firestore.firestore()) {
        self.uid = uid
        self.db = firestore
    }

    public func setDisplayName(displayName: String) async throws {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }

        let snapshot = try await userDoc.getDocument()
        let data = snapshot.data() ?? [:]
        let usernameLower = ((data["usernameLower"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let payload: [String: Any] = [
            "displayName": name,
            "displayNameLower": name.lowercased(),
            "searchTokens": Self.buildSearchTokens(displayName: name, username: usernameLower),
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        try await userDoc.setData(payload, merge: true)
        try await publicProfileDoc.setData(payload, merge: true)

        if !usernameLower.isEmpty {
            try await usernamesCollection.document(usernameLower).setData(
                [
                    "displayName": name,
                    "updatedAt": FieldValue.serverTimestamp(),
                ],
                merge: true
            )
        }
    }

    public func updateProfilePhoto(photoUrl: String) async throws {
        let url = photoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            return
        }

        let snapshot = try await userDoc.getDocument()
        let usernameLower = ((snapshot.data() ?? [:])["usernameLower"] as? String) ?? ""

        let payload: [String: Any] = [
            "photoUrl": url,
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        try await userDoc.setData(payload, merge: true)
        try await publicProfileDoc.setData(payload, merge: true)

        let normalizedUsername = usernameLower.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedUsername.isEmpty {
            try await usernamesCollection.document(normalizedUsername).setData(payload, merge: true)
        }
    }

    public func getPublicProfilesByUids(_ uids: [String]) async throws -> [PublicProfile] {
        let cleaned = Array(Set(
            uids
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        ))

        guard !cleaned.isEmpty else {
            return []
        }

        var profiles: [PublicProfile] = []
        var found = Set<String>()

        for chunk in cleaned.chunked(into: 10) {
            let snapshot = try await publicProfilesCollection
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for document in snapshot.documents {
                found.insert(document.documentID)
                profiles.append(mapPublicProfile(documentID: document.documentID, data: document.data()))
            }
        }

        let missing = cleaned.filter { !found.contains($0) }
        for chunk in missing.chunked(into: 10) {
            let snapshot = try await db
                .collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for document in snapshot.documents {
                profiles.append(mapPublicProfile(documentID: document.documentID, data: document.data()))
            }
        }

        return profiles
    }

    public func lookupExistingUsersByPhones(_ phones: [String]) async throws -> [String: String] {
        let normalized = Array(Set(
            phones
                .map(Self.normalizePhone)
                .filter { !$0.isEmpty }
        ))

        guard !normalized.isEmpty else {
            return [:]
        }

        var output: [String: String] = [:]

        for chunk in normalized.chunked(into: 10) {
            let snapshot = try await phonesCollection
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for document in snapshot.documents {
                let data = document.data()
                let foundUid = strictStringOrEmpty(data["uid"])
                if !foundUid.isEmpty {
                    output[document.documentID] = foundUid
                }
            }
        }

        return output
    }

    public func ensureDefaultCircleId() async throws -> String {
        try await ensureHasAtLeastOneCircle()

        let snapshot = try await circlesCollection
            .order(by: "index", descending: false)
            .limit(to: 1)
            .getDocuments()

        if let first = snapshot.documents.first {
            return first.documentID
        }

        return try await createCircle(name: "Circle 1", index: 0)
    }

    public func addMembersBulk(circleId: String, members: [CircleSeedMember]) async throws {
        guard !members.isEmpty else {
            return
        }

        let membersCollection = circlesCollection.document(circleId).collection("members")
        let batch = db.batch()

        for member in members {
            var memberId = member.memberId.trimmingCharacters(in: .whitespacesAndNewlines)
            if memberId.isEmpty {
                memberId = generatedMemberId(for: member.displayName)
            }

            let cleanedUid = (member.uid ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedName = member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedUsername = (member.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedPhone = (member.phoneE164 ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let isRealUser = !cleanedUid.isEmpty

            guard !cleanedName.isEmpty else {
                continue
            }

            let payload = mapCircleSeedMemberPayload(
                seed: member,
                memberId: memberId,
                cleanedUid: cleanedUid,
                cleanedName: cleanedName,
                cleanedUsername: cleanedUsername,
                cleanedPhone: cleanedPhone,
                isRealUser: isRealUser
            )

            batch.setData(payload, forDocument: membersCollection.document(memberId), merge: true)
        }

        try await batch.commit()
    }

    public func streamCircles() -> AsyncThrowingStream<[UserCircle], Error> {
        AsyncThrowingStream { continuation in
            let listener = circlesCollection
                .order(by: "index", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    let circles = snapshot?.documents.map { document in
                        self.mapUserCircle(documentID: document.documentID, data: document.data())
                    } ?? []

                    continuation.yield(circles)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    public func streamMembers(circleId: String) -> AsyncThrowingStream<[CircleMember], Error> {
        AsyncThrowingStream { continuation in
            let listener = circlesCollection
                .document(circleId)
                .collection("members")
                .order(by: "addedAt", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    let members = snapshot?.documents.map { document in
                        self.mapCircleMember(documentID: document.documentID, data: document.data())
                    } ?? []

                    continuation.yield(members)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    public func removeMember(circleId: String, memberId: String) async throws {
        try await circlesCollection
            .document(circleId)
            .collection("members")
            .document(memberId)
            .delete()
    }

    public func ensureHasAtLeastOneCircle() async throws {
        let circlesSnapshot = try await circlesCollection.limit(to: 1).getDocuments()
        if !circlesSnapshot.documents.isEmpty {
            return
        }

        let circleId = try await createCircle(name: "Circle 1", index: 0)
        let legacySnapshot = try await legacyMystosCollection.getDocuments()
        if legacySnapshot.documents.isEmpty {
            return
        }

        let batch = db.batch()
        for document in legacySnapshot.documents {
            let data = document.data()
            let rawName = strictStringOrEmpty(data["displayName"])
            let cleanedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanedName.isEmpty else {
                continue
            }

            let memberId = "m_\(document.documentID)"
            let memberRef = circlesCollection.document(circleId).collection("members").document(memberId)

            batch.setData(
                [
                    "memberId": memberId,
                    "uid": NSNull(),
                    "displayName": cleanedName,
                    "username": "",
                    "phoneE164": "",
                    "onKetchUp": false,
                    "addedAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                ],
                forDocument: memberRef,
                merge: true
            )
        }

        try await batch.commit()
    }

    private var userDoc: DocumentReference {
        db.collection("users").document(uid)
    }

    private var publicProfilesCollection: CollectionReference {
        db.collection("publicProfiles")
    }

    private var publicProfileDoc: DocumentReference {
        publicProfilesCollection.document(uid)
    }

    private var circlesCollection: CollectionReference {
        userDoc.collection("circles")
    }

    private var legacyMystosCollection: CollectionReference {
        userDoc.collection("mystos")
    }

    private var usernamesCollection: CollectionReference {
        db.collection("usernames")
    }

    private var phonesCollection: CollectionReference {
        db.collection("phones")
    }

    private func createCircle(name: String, index: Int) async throws -> String {
        let document = circlesCollection.document()
        try await document.setData(
            [
                "name": name,
                "index": index,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ]
        )
        return document.documentID
    }

    private func mapCircleMember(documentID: String, data: [String: Any]) -> CircleMember {
        CircleMember(
            id: documentID,
            displayName: stringDescriptionOrEmpty(data["displayName"]),
            onKetchUp: boolOrDefault(data["onKetchUp"], default: false),
            uid: nilIfEmptyStringDescription(data["uid"]),
            username: nilIfEmptyStringDescription(data["username"]),
            phoneE164: nilIfEmptyStringDescription(data["phoneE164"])
        )
    }

    private func mapPublicProfile(documentID: String, data: [String: Any]) -> PublicProfile {
        let rawPhotoUrl = strictStringOrEmpty(data["photoUrl"])
        let normalizedPhotoUrl = rawPhotoUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        return PublicProfile(
            uid: documentID,
            displayName: strictStringOrEmpty(data["displayName"]),
            username: strictStringOrEmpty(data["username"]),
            phoneE164: strictStringOrEmpty(data["phoneE164"]),
            photoUrl: normalizedPhotoUrl.isEmpty ? nil : rawPhotoUrl
        )
    }

    private func mapUserCircle(documentID: String, data: [String: Any]) -> UserCircle {
        UserCircle(
            id: documentID,
            name: strictStringOrDefault(data["name"], default: "Circle"),
            index: intOrDefault(data["index"], default: 0)
        )
    }

    private func mapCircleSeedMemberPayload(
        seed: CircleSeedMember,
        memberId: String,
        cleanedUid: String,
        cleanedName: String,
        cleanedUsername: String,
        cleanedPhone: String,
        isRealUser: Bool
    ) -> [String: Any] {
        _ = seed

        return [
            "memberId": memberId,
            "uid": isRealUser ? cleanedUid : NSNull(),
            "displayName": cleanedName,
            "username": cleanedUsername,
            "phoneE164": cleanedPhone,
            "onKetchUp": isRealUser,
            "addedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
    }

    private static func cleanToken(_ input: String) -> String {
        let lowered = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }

        let cleaned = String(scalars)
        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func generatedMemberId(for displayName: String) -> String {
        let timestampMs = Int(Date().timeIntervalSince1970 * 1000)
            // Dart String.hashCode is not available in Swift, so this preserves the
            // timestamp-plus-string-hash shape using Swift's closest built-in equivalent.
            return "m_\(timestampMs)_\(displayName.hashValue)"
    }

    private func stringDescriptionOrEmpty(_ raw: Any?) -> String {
        guard let raw else {
            return ""
        }
        return String(describing: raw)
    }

    private func nilIfEmptyStringDescription(_ raw: Any?) -> String? {
        let value = stringDescriptionOrEmpty(raw)
        return value.isEmpty ? nil : value
    }

    private func strictStringOrEmpty(_ raw: Any?) -> String {
        raw as? String ?? ""
    }

    private func strictStringOrDefault(_ raw: Any?, default defaultValue: String) -> String {
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

        return defaultValue
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else {
            return isEmpty ? [] : [self]
        }

        var index = 0
        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)

        while index < count {
            let endIndex = Swift.min(index + size, count)
            chunks.append(Array(self[index..<endIndex]))
            index = endIndex
        }

        return chunks
    }
}