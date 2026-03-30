import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../storage.dart';
import 'progress_service.dart';

class FriendsGraphService {
static final FirebaseFirestore _db = FirebaseFirestore.instance;

static String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

static DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
return _db.collection('users').doc(uid);
}

static CollectionReference<Map<String, dynamic>> _circlesCol(String uid) {
return _userDoc(uid).collection('circles');
}

static CollectionReference<Map<String, dynamic>> _membersCol({
required String uid,
required String circleId,
}) {
return _circlesCol(uid).doc(circleId).collection('members');
}

/// Kept only for compatibility with old UI.
/// This is NOT source-of-truth matching data.
static List<String> getMyFriendsLocal() {
final raw = AppStorage.getCircle();
final cleaned = raw
.map((e) => e.trim())
.where((e) => e.isNotEmpty)
.toSet()
.toList()
..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
return cleaned;
}

static Future<String?> _resolveCircleIdForUser(String uid) async {
if (uid == _currentUid) {
final saved = (AppStorage.getSelectedCircleId() ?? '').trim();
if (saved.isNotEmpty) return saved;
}

final snap = await _circlesCol(uid)
.orderBy('index', descending: false)
.limit(1)
.get();

if (snap.docs.isEmpty) return null;
return snap.docs.first.id;
}

static String? _nullableTrimmed(dynamic value) {
final s = (value ?? '').toString().trim();
return s.isEmpty ? null : s;
}

static GraphMember _memberFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
final data = doc.data() ?? <String, dynamic>{};

final uid = _nullableTrimmed(data['uid']);
final onKetchUpRaw = data['onKetchUp'];
final onKetchUp = onKetchUpRaw is bool ? onKetchUpRaw : uid != null;

return GraphMember(
id: doc.id,
uid: uid,
displayName: _nullableTrimmed(data['displayName']) ?? '',
username: _nullableTrimmed(data['username']),
phoneE164: _nullableTrimmed(data['phoneE164']),
onKnowNoKnow: onKetchUp,
);
}

static bool _isStrictRealUser(GraphMember m) {
return m.isRealUser && m.onKnowNoKnow;
}

/// All real members in the active circle for the signed-in user.
static Future<List<GraphMember>> getMyCircleMembers() async {
final uid = _currentUid;
if (uid == null) return [];

final circleId = await _resolveCircleIdForUser(uid);
if (circleId == null) return [];

final snap = await _membersCol(uid: uid, circleId: circleId).get();

final members = snap.docs.map(_memberFromDoc).where(_isStrictRealUser).toList()
..sort((a, b) =>
a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

return members;
}

static Future<List<GraphMember>> getMyOnAppCircleMembers() async {
return getMyCircleMembers();
}

static Future<List<GraphMember>> getValidMatchPool() async {
final members = await getMyCircleMembers();
return members.where(_isStrictRealUser).toList()
..sort((a, b) =>
a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
}

static Future<bool> hasValidMatchPool({int min = 3}) async {
final pool = await getValidMatchPool();
return pool.length >= min;
}

static Future<List<String>> getMyOnAppFriendUids() async {
final members = await getMyCircleMembers();
return members.map((m) => m.uid!).toSet().toList()..sort();
}

static Future<List<String>> getValidMatchUids() async {
final pool = await getValidMatchPool();
return pool.map((m) => m.uid!).toSet().toList()..sort();
}

static Future<List<String>> getMyOnAppFriendNames() async {
final members = await getMyCircleMembers();
return members
.map((m) => m.displayName.trim())
.where((s) => s.isNotEmpty)
.toSet()
.toList()
..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

static Future<int> getMyCircleCount() async {
final members = await getMyCircleMembers();
return members.length;
}

static Future<int> getMyOnAppFriendCount() async {
final uids = await getValidMatchUids();
return uids.length;
}

static Future<bool> hasMinimumOnAppFriends({int minCount = 3}) async {
final count = await getMyOnAppFriendCount();
return count >= minCount;
}

static Future<List<GraphMember>> getOnAppFriendsForUserUid(
String userUid,
) async {
final circleId = await _resolveCircleIdForUser(userUid);
if (circleId == null) return [];

final snap = await _membersCol(uid: userUid, circleId: circleId).get();

final members = snap.docs.map(_memberFromDoc).where(_isStrictRealUser).toList()
..sort((a, b) =>
a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

return members;
}

static Future<List<GraphMember>> getRecentlyActiveOnAppFriendsForUserUid(
String userUid, {
int maxInactiveDays = 3,
}) async {
final members = await getOnAppFriendsForUserUid(userUid);
if (members.isEmpty) return [];

final active = <GraphMember>[];
for (final member in members) {
final uid = member.uid;
if (uid == null) continue;

try {
final userSnap = await _db.collection('users').doc(uid).get();
if (!userSnap.exists) continue;

final data = userSnap.data() ?? <String, dynamic>{};
final raw = data['lastActiveAtMs'];

int? lastActiveAtMs;
if (raw is int) {
lastActiveAtMs = raw;
} else if (raw is num) {
lastActiveAtMs = raw.toInt();
}

if (lastActiveAtMs == null) continue;

final nowMs = DateTime.now().millisecondsSinceEpoch;
final gapMs = nowMs - lastActiveAtMs;
if (gapMs <= Duration(days: maxInactiveDays).inMilliseconds) {
active.add(member);
}
} catch (_) {
continue;
}
}

return active;
}

static Future<List<GraphMember>> getFriendsOfFriends() async {
final myUid = _currentUid;
if (myUid == null) return [];

final direct = await getValidMatchPool();
final directUids = direct.map((m) => m.uid!).toSet();

if (directUids.isEmpty) return [];

final futures = directUids.map(getOnAppFriendsForUserUid).toList();
final results = await Future.wait(futures);

final fofMap = <String, GraphMember>{};

for (final list in results) {
for (final candidate in list) {
final uid = candidate.uid!;
if (uid == myUid) continue;
if (directUids.contains(uid)) continue;
fofMap[uid] = candidate;
}
}

final out = fofMap.values.toList()
..sort((a, b) =>
a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

return out;
}

static Future<List<String>> getFriendsOfFriendsUids() async {
final fof = await getFriendsOfFriends();
return fof.map((m) => m.uid!).toList();
}

static Future<List<String>> getFriendsOfFriendsNames() async {
final fof = await getFriendsOfFriends();
return fof
.map((m) => m.displayName.trim())
.where((s) => s.isNotEmpty)
.toList()
..toSet()
..toList();
}

static Future<bool> isInMyOnAppCircle(String otherUid) async {
final uids = await getValidMatchUids();
return uids.contains(otherUid);
}

static Future<bool> isCurrentUserRecentlyActive({
int maxInactiveDays = 3,
}) async {
return ProgressService.isRecentlyActive(maxInactiveDays: maxInactiveDays);
}
}

class GraphMember {
final String id;
final String? uid;
final String displayName;
final String? username;
final String? phoneE164;
final bool onKnowNoKnow;

const GraphMember({
required this.id,
required this.uid,
required this.displayName,
required this.username,
required this.phoneE164,
required this.onKnowNoKnow,
});

bool get isRealUser => uid != null && uid!.trim().isNotEmpty;
}