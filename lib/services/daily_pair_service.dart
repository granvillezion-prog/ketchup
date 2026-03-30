import 'dart:math' show Random;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';
import '../storage.dart';
import 'friends_graph_service.dart';
import 'progress_service.dart';

class DailyPairService {
static const List<String> questions = [
"What’s something that made you laugh recently?",
"What’s your favorite meal ever?",
"What’s one habit you’re trying to build?",
"What’s a memory you keep replaying lately?",
];

static const Map<int, List<String>> _answerBank = {
0: [
"A dog tried to carry three tennis balls at once and failed.",
"My friend texted the wrong person and doubled down.",
"I watched a kid narrate his own life like a documentary.",
"Someone confidently gave directions… to the wrong place.",
],
1: [
"My mom’s cooking — nothing comes close.",
"A perfect burger + crispy fries.",
"Sushi when it’s actually elite.",
"Breakfast for dinner. Always.",
],
2: [
"Stop scrolling first thing in the morning.",
"Reading 10 pages a day, no matter what.",
"Daily steps — trying to stay consistent.",
"Going to sleep earlier like an adult.",
],
3: [
"That one summer where everything felt possible.",
"A random conversation that hit way harder than it should’ve.",
"A moment I wish I handled differently.",
"A win I didn’t celebrate enough.",
],
};

static const int _recentRepeatWindowDays = 5;
static const int _maxInactiveDaysForMatching = 3;

static FirebaseFirestore get _db => FirebaseFirestore.instance;

static String _dateKeyFromDateTime(DateTime dt) {
final y = dt.year.toString().padLeft(4, '0');
final m = dt.month.toString().padLeft(2, '0');
final d = dt.day.toString().padLeft(2, '0');
return '$y-$m-$d';
}

static String dateKeyNow() => _dateKeyFromDateTime(DateTime.now());

static String dateKeyFromMs(int ms) {
return _dateKeyFromDateTime(DateTime.fromMillisecondsSinceEpoch(ms));
}

static String effectiveKeyNowOrCallStart() {
final startedAt = AppStorage.getCallStartedAt();
if (startedAt != null) return dateKeyFromMs(startedAt);
return dateKeyNow();
}

static Random _rngForDay(String uid, String key) {
final seed = '$uid|$key'
.codeUnits
.fold<int>(0, (acc, v) => ((acc * 31) + v) & 0x7fffffff);
return Random(seed);
}

static String _pickAnswer({
required Random rng,
required int qIndex,
}) {
final list = _answerBank[qIndex];
if (list == null || list.isEmpty) return '…';
return list[rng.nextInt(list.length)];
}

static CollectionReference<Map<String, dynamic>> _dailyUsersCol(String key) {
return _db.collection('daily_assignments').doc(key).collection('users');
}

static DocumentReference<Map<String, dynamic>> _dailyUserDoc(
String key,
String uid,
) {
return _dailyUsersCol(key).doc(uid);
}

static CollectionReference<Map<String, dynamic>> _dailyPoolCol(String key) {
return _db.collection('daily_pool').doc(key).collection('users');
}

static CollectionReference<Map<String, dynamic>> _dailyMatchesCol(String key) {
return _db.collection('daily_matches').doc(key).collection('pairs');
}

static CollectionReference<Map<String, dynamic>> get _pairHistoryCol =>
_db.collection('pair_history');

static Future<void> _resetIfNewKey(String key) async {
final stored = AppStorage.getStoredTodayKey();
if (stored == key) return;

await AppStorage.setStoredTodayKey(key);
await AppStorage.clearDailyCallState();
await AppStorage.clearTodayPair();
}

static Future<void> ensureTodayPair() async {
final key = effectiveKeyNowOrCallStart();
await _resetIfNewKey(key);

final existing = AppStorage.getTodayPair();
if (AppStorage.getCallStartedAt() != null) {
if (existing != null && existing.dateKey == key) return;
}

if (existing != null && existing.dateKey == key && !existing.callCompleted) {
return;
}

final uid = FirebaseAuth.instance.currentUser?.uid;
if (uid == null) return;

await ProgressService.ensureUserDoc();

final shared = await _dailyUserDoc(key, uid).get();
if (shared.exists) {
final pair = await _pairFromAssignmentDoc(
key: key,
data: shared.data() ?? <String, dynamic>{},
);
await AppStorage.setTodayPair(pair);
if (!pair.callCompleted) return;
}

final day = await ProgressService.getDay(key);
if (day != null) {
final hydrated = await _pairFromDayMap(
key: key,
day: day,
);
await AppStorage.setTodayPair(hydrated);
if (!hydrated.callCompleted) return;
}

await _joinDailyPool(key: key, uid: uid);
await runGlobalMatching(key);

final assigned = await _dailyUserDoc(key, uid).get();
if (assigned.exists) {
final pair = await _pairFromAssignmentDoc(
key: key,
data: assigned.data() ?? <String, dynamic>{},
);
await AppStorage.setTodayPair(pair);

await ProgressService.setDay(key, {
'dateKey': pair.dateKey,
'hiddenName': pair.hiddenName,
'phone': pair.phone,
'questionId': pair.questionId,
'questionText': pair.questionText,
'answerText': pair.answerText,
'callCompleted': pair.callCompleted,
'circleId': pair.circleId,
'circleName': pair.circleName,
'callIndex': pair.callIndex,
'totalCalls': pair.totalCalls,
'partnerUid': pair.partnerUid,
'partnerUsername': pair.partnerUsername,
'pairVersion': 8,
'updatedAt': FieldValue.serverTimestamp(),
});
return;
}

final noPair = await _buildNoFriendsPair(key: key);
await _persistSingleAssignment(
key: key,
currentUid: uid,
pair: noPair,
state: 'unmatched_priority_tomorrow',
allowLateJoin: false,
);
await AppStorage.setTodayPair(noPair);
}

static Future<void> _joinDailyPool({
required String key,
required String uid,
}) async {
await _dailyPoolCol(key).doc(uid).set({
'uid': uid,
'joinedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
}

static Future<bool> _isEligibleForMatching(String uid) async {
try {
final userSnap = await _db.collection('users').doc(uid).get();
if (!userSnap.exists) return false;

final data = userSnap.data() ?? <String, dynamic>{};
final lastActiveRaw = data['lastActiveAtMs'];

int? lastActiveAtMs;
if (lastActiveRaw is int) {
lastActiveAtMs = lastActiveRaw;
} else if (lastActiveRaw is num) {
lastActiveAtMs = lastActiveRaw.toInt();
}

if (lastActiveAtMs == null) return false;

final nowMs = DateTime.now().millisecondsSinceEpoch;
final maxGapMs =
Duration(days: _maxInactiveDaysForMatching).inMilliseconds;

return (nowMs - lastActiveAtMs) <= maxGapMs;
} catch (_) {
return false;
}
}

static Future<void> runGlobalMatching(String key) async {
final poolSnap = await _dailyPoolCol(key).get();
final rawPoolUids = poolSnap.docs.map((d) => d.id).toSet().toList();

final poolUids = <String>[];
for (final uid in rawPoolUids) {
final eligible = await _isEligibleForMatching(uid);
if (eligible) {
poolUids.add(uid);
}
}

if (poolUids.length < 2) return;

final assigned = <String>{};
final directCache = <String, List<GraphMember>>{};
final directUidSetCache = <String, Set<String>>{};
final reserveEligibleCache = <String, bool>{};
final profileCache = <String, _MiniProfile>{};

for (final uid in poolUids) {
if (await _userHasAssignment(key, uid)) {
assigned.add(uid);
}
}

final available = poolUids.where((u) => !assigned.contains(u)).toList();
if (available.length < 2) return;

available.shuffle();

while (available.length >= 2) {
final userA = available.removeAt(0);

String? bestPartner;
int bestScore = -1 << 30;

for (final userB in available) {
final score = await _scorePairGlobal(
key: key,
userA: userA,
userB: userB,
directCache: directCache,
directUidSetCache: directUidSetCache,
rng: _rngForDay(userA, '$key|$userB'),
);

if (score > bestScore) {
bestScore = score;
bestPartner = userB;
}
}

if (bestPartner == null) {
continue;
}

final created = await _createGlobalPrimaryMatch(
key: key,
userA: userA,
userB: bestPartner,
directCache: directCache,
directUidSetCache: directUidSetCache,
reserveEligibleCache: reserveEligibleCache,
profileCache: profileCache,
);

if (created) {
available.remove(bestPartner);
assigned.add(userA);
assigned.add(bestPartner);
}
}

if (available.isNotEmpty) {
final lonely = available.first;
await _assignLonelyUserToReserve(
key: key,
lonelyUid: lonely,
poolUids: poolUids,
reserveEligibleCache: reserveEligibleCache,
profileCache: profileCache,
);
}
}

static Future<bool> _userHasAssignment(String key, String uid) async {
final snap = await _dailyUserDoc(key, uid).get();
return snap.exists;
}

static Future<int> _scorePairGlobal({
required String key,
required String userA,
required String userB,
required Map<String, List<GraphMember>> directCache,
required Map<String, Set<String>> directUidSetCache,
required Random rng,
}) async {
final aDirect = await _getDirectFriendsCached(
userA,
directCache,
directUidSetCache,
);
final bDirect = await _getDirectFriendsCached(
userB,
directCache,
directUidSetCache,
);

final aSet = directUidSetCache[userA] ?? <String>{};
final bSet = directUidSetCache[userB] ?? <String>{};

final mutual = aSet.intersection(bSet).length;
final aHasBDirect = aSet.contains(userB);
final bHasADirect = bSet.contains(userA);
final pairedRecently = await _werePairedRecently(
userA: userA,
userB: userB,
limitDays: _recentRepeatWindowDays,
);

int score = 0;

if (aHasBDirect && bHasADirect) {
score += 500;
} else if (aHasBDirect || bHasADirect) {
score += 340;
} else {
score += 180;
}

if (pairedRecently) {
score -= 950;
}

score += mutual * 35;

if (aDirect.length <= 2) score += 120;
if (bDirect.length <= 2) score += 120;

if (aDirect.length <= 4) score += 50;
if (bDirect.length <= 4) score += 50;

if (aDirect.length >= 10) score -= 20;
if (bDirect.length >= 10) score -= 20;

score += rng.nextInt(11);

return score;
}

static Future<List<GraphMember>> _getDirectFriendsCached(
String uid,
Map<String, List<GraphMember>> directCache,
Map<String, Set<String>> directUidSetCache,
) async {
final existing = directCache[uid];
if (existing != null) return existing;

final friends = await FriendsGraphService.getOnAppFriendsForUserUid(uid);
directCache[uid] = friends;
directUidSetCache[uid] =
friends.map((m) => m.uid).whereType<String>().toSet();
return friends;
}

static Future<bool> _createGlobalPrimaryMatch({
required String key,
required String userA,
required String userB,
required Map<String, List<GraphMember>> directCache,
required Map<String, Set<String>> directUidSetCache,
required Map<String, bool> reserveEligibleCache,
required Map<String, _MiniProfile> profileCache,
}) async {
final qRng = _rngForDay(userA, '$key|$userB|pair');
final qIndex = qRng.nextInt(questions.length);
final qId = 'q$qIndex';
final qText = questions[qIndex];
final aText = _pickAnswer(rng: qRng, qIndex: qIndex);

final progressA = await ProgressService.getUserProgress();
final pointsA = (progressA['points'] ?? 0) as int;
final currentStreakA = (progressA['currentStreak'] ?? 0) as int;
final longestStreakA = (progressA['longestStreak'] ?? 0) as int;
final lastCallAtMsA = progressA['lastCallAtMs'] as int?;

final profileA = await _getMiniProfile(userA, profileCache);
final profileB = await _getMiniProfile(userB, profileCache);

final directA = await _getDirectFriendsCached(
userA,
directCache,
directUidSetCache,
);
final directSetA = directUidSetCache[userA] ?? <String>{};
final tierForA = directSetA.contains(userB)
? _CandidateTier.directOnApp
: _CandidateTier.friendOfFriend;

final allowLateJoinForA = await _isReserveEligibleCached(
userA,
reserveEligibleCache,
);
final allowLateJoinForB = await _isReserveEligibleCached(
userB,
reserveEligibleCache,
);

final pairForA = MockPair(
dateKey: key,
hiddenName: profileB.displayName,
phone: profileB.phone,
questionId: qId,
questionText: qText,
answerText: aText,
callCompleted: false,
points: pointsA,
currentStreak: currentStreakA,
longestStreak: longestStreakA,
lastCallAtMs: lastCallAtMsA,
circleId: '',
circleName: tierForA.storageLabel,
callIndex: 1,
totalCalls: 1,
partnerUid: userB,
partnerUsername: profileB.username.isEmpty ? null : profileB.username,
);

try {
await _db.runTransaction((tx) async {
final aRef = _dailyUserDoc(key, userA);
final bRef = _dailyUserDoc(key, userB);

final aSnap = await tx.get(aRef);
final bSnap = await tx.get(bRef);

if (aSnap.exists || bSnap.exists) {
return;
}

tx.set(aRef, {
'userId': userA,
'partnerUid': userB,
'partnerUsername':
profileB.username.isEmpty ? null : profileB.username,
'hiddenName': profileB.displayName,
'phone': profileB.phone,
'questionId': qId,
'questionText': qText,
'answerText': aText,
'callCompleted': false,
'state': 'matched_primary',
'allowLateJoin': allowLateJoinForA,
'circleId': '',
'circleName': tierForA.storageLabel,
'callIndex': 1,
'totalCalls': 1,
'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

final tierForB =
directA.any((m) => (m.uid ?? '').trim() == userB)
? _CandidateTier.directOnApp
: _CandidateTier.friendOfFriend;

tx.set(bRef, {
'userId': userB,
'partnerUid': userA,
'partnerUsername':
profileA.username.isEmpty ? null : profileA.username,
'hiddenName': profileA.displayName,
'phone': profileA.phone,
'questionId': qId,
'questionText': qText,
'answerText': aText,
'callCompleted': false,
'state': 'matched_primary',
'allowLateJoin': allowLateJoinForB,
'circleId': '',
'circleName': tierForB.storageLabel,
'callIndex': 1,
'totalCalls': 1,
'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

final ids = [userA, userB]..sort();
tx.set(
_dailyMatchesCol(key).doc('${ids[0]}_${ids[1]}'),
{
'uids': ids,
'createdAt': FieldValue.serverTimestamp(),
'state': 'matched_primary',
},
SetOptions(merge: true),
);
});
} catch (_) {
return false;
}

await _writePairHistory(
userA: userA,
userB: userB,
key: key,
);

return true;
}

static Future<void> _assignLonelyUserToReserve({
required String key,
required String lonelyUid,
required List<String> poolUids,
required Map<String, bool> reserveEligibleCache,
required Map<String, _MiniProfile> profileCache,
}) async {
if (await _userHasAssignment(key, lonelyUid)) return;

String? reserveUid;

for (final uid in poolUids) {
if (uid == lonelyUid) continue;
if (!await _userHasAssignment(key, uid)) continue;
if (!await _isEligibleForMatching(uid)) continue;

final eligible = await _isReserveEligibleCached(uid, reserveEligibleCache);
if (!eligible) continue;

reserveUid = uid;
break;
}

if (reserveUid == null) {
final noPair = await _buildNoFriendsPair(key: key);
await _persistSingleAssignment(
key: key,
currentUid: lonelyUid,
pair: noPair,
state: 'unmatched_priority_tomorrow',
allowLateJoin: false,
);
return;
}

final profile = await _getMiniProfile(reserveUid, profileCache);
final qRng = _rngForDay(lonelyUid, '$key|reserve|$reserveUid');
final qIndex = qRng.nextInt(questions.length);
final qId = 'q$qIndex';
final qText = questions[qIndex];
final aText = _pickAnswer(rng: qRng, qIndex: qIndex);

final progress = await ProgressService.getUserProgress();
final points = (progress['points'] ?? 0) as int;
final currentStreak = (progress['currentStreak'] ?? 0) as int;
final longestStreak = (progress['longestStreak'] ?? 0) as int;
final lastCallAtMs = progress['lastCallAtMs'] as int?;

final pair = MockPair(
dateKey: key,
hiddenName: profile.displayName,
phone: profile.phone,
questionId: qId,
questionText: qText,
answerText: aText,
callCompleted: false,
points: points,
currentStreak: currentStreak,
longestStreak: longestStreak,
lastCallAtMs: lastCallAtMs,
circleId: '',
circleName: 'late_join_reserve',
callIndex: 1,
totalCalls: 1,
partnerUid: reserveUid,
partnerUsername: profile.username.isEmpty ? null : profile.username,
);

await _persistSingleAssignment(
key: key,
currentUid: lonelyUid,
pair: pair,
state: 'late_join_reserve',
allowLateJoin: false,
);

await _writePairHistory(
userA: lonelyUid,
userB: reserveUid,
key: key,
);
}

static Future<bool> _isReserveEligibleCached(
String uid,
Map<String, bool> cache,
) async {
final cached = cache[uid];
if (cached != null) return cached;

final eligible = await _isReserveEligible(uid);
cache[uid] = eligible;
return eligible;
}

static Future<_MiniProfile> _getMiniProfile(
String uid,
Map<String, _MiniProfile> cache,
) async {
final existing = cache[uid];
if (existing != null) return existing;

final profile = await _profileForUid(uid);
cache[uid] = profile;
return profile;
}

static Future<_MiniProfile> _profileForUid(String uid) async {
try {
final publicSnap = await _db.collection('publicProfiles').doc(uid).get();
if (publicSnap.exists) {
final data = publicSnap.data() ?? <String, dynamic>{};
return _MiniProfile(
displayName: ((data['displayName'] ?? '') as String).trim().isEmpty
? 'Mysto'
: ((data['displayName'] ?? '') as String).trim(),
username: ((data['username'] ?? '') as String).trim(),
phone: ((data['phoneE164'] ?? '') as String).trim(),
);
}

final userSnap = await _db.collection('users').doc(uid).get();
if (userSnap.exists) {
final data = userSnap.data() ?? <String, dynamic>{};
return _MiniProfile(
displayName: ((data['displayName'] ?? '') as String).trim().isEmpty
? 'Mysto'
: ((data['displayName'] ?? '') as String).trim(),
username: ((data['username'] ?? '') as String).trim(),
phone: ((data['phoneE164'] ?? '') as String).trim(),
);
}
} catch (_) {}

return const _MiniProfile(
displayName: 'Mysto',
username: '',
phone: '',
);
}

static Future<MockPair> _pairFromAssignmentDoc({
required String key,
required Map<String, dynamic> data,
}) async {
final progress = await ProgressService.getUserProgress();
final points = (progress['points'] ?? 0) as int;
final currentStreak = (progress['currentStreak'] ?? 0) as int;
final longestStreak = (progress['longestStreak'] ?? 0) as int;
final lastCallAtMs = progress['lastCallAtMs'] as int?;

final hiddenName = (data['hiddenName'] ?? 'Mysto').toString();
final phone = (data['phone'] ?? '').toString();

final partnerUid = (data['partnerUid'] ?? '').toString().trim();
final partnerUsername = (data['partnerUsername'] ?? '').toString().trim();

return MockPair(
dateKey: key,
hiddenName: hiddenName,
phone: phone,
questionId: (data['questionId'] ?? 'q0').toString(),
questionText: (data['questionText'] ?? '').toString(),
answerText: (data['answerText'] ?? '').toString(),
callCompleted: (data['callCompleted'] ?? false) as bool,
points: points,
currentStreak: currentStreak,
longestStreak: longestStreak,
lastCallAtMs: lastCallAtMs,
circleId: (data['circleId'] ?? '').toString(),
circleName: (data['circleName'] ?? '').toString(),
callIndex: (data['callIndex'] ?? 1) as int,
totalCalls: (data['totalCalls'] ?? 1) as int,
partnerUid: partnerUid.isEmpty ? null : partnerUid,
partnerUsername: partnerUsername.isEmpty ? null : partnerUsername,
);
}

static Future<MockPair> _pairFromDayMap({
required String key,
required Map<String, dynamic> day,
}) async {
final progress = await ProgressService.getUserProgress();
final points = (progress['points'] ?? 0) as int;
final currentStreak = (progress['currentStreak'] ?? 0) as int;
final longestStreak = (progress['longestStreak'] ?? 0) as int;
final lastCallAtMs = progress['lastCallAtMs'] as int?;

final hiddenName = (day['hiddenName'] ?? 'Mysto').toString();
final phone = (day['phone'] ?? '').toString();

final partnerUid = (day['partnerUid'] ?? '').toString().trim();
final partnerUsername = (day['partnerUsername'] ?? '').toString().trim();

return MockPair(
dateKey: key,
hiddenName: hiddenName,
phone: phone,
questionId: (day['questionId'] ?? 'q0').toString(),
questionText: (day['questionText'] ?? '').toString(),
answerText: (day['answerText'] ?? '').toString(),
callCompleted: (day['callCompleted'] ?? false) as bool,
points: points,
currentStreak: currentStreak,
longestStreak: longestStreak,
lastCallAtMs: lastCallAtMs,
circleId: (day['circleId'] ?? '').toString(),
circleName: (day['circleName'] ?? '').toString(),
callIndex: (day['callIndex'] ?? 1) as int,
totalCalls: (day['totalCalls'] ?? 1) as int,
partnerUid: partnerUid.isEmpty ? null : partnerUid,
partnerUsername: partnerUsername.isEmpty ? null : partnerUsername,
);
}

static Future<void> _persistSingleAssignment({
required String key,
required String currentUid,
required MockPair pair,
required String state,
required bool allowLateJoin,
}) async {
await _dailyUserDoc(key, currentUid).set({
'userId': currentUid,
'partnerUid': pair.partnerUid,
'partnerUsername': pair.partnerUsername,
'hiddenName': pair.hiddenName,
'phone': pair.phone,
'questionId': pair.questionId,
'questionText': pair.questionText,
'answerText': pair.answerText,
'callCompleted': false,
'state': state,
'allowLateJoin': allowLateJoin,
'circleId': pair.circleId,
'circleName': pair.circleName,
'callIndex': pair.callIndex,
'totalCalls': pair.totalCalls,
'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
}

static Future<void> _writePairHistory({
required String userA,
required String userB,
required String key,
}) async {
final ids = [userA, userB]..sort();
final historyId = '${key}_${ids[0]}_${ids[1]}';

await _pairHistoryCol.doc(historyId).set({
'userA': ids[0],
'userB': ids[1],
'dayKey': key,
'pairedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
}

static Future<bool> _werePairedRecently({
required String userA,
required String userB,
required int limitDays,
}) async {
final ids = [userA, userB]..sort();

final now = DateTime.now();
final start = now.subtract(Duration(days: limitDays));

final snap = await _pairHistoryCol
.where('userA', isEqualTo: ids[0])
.where('userB', isEqualTo: ids[1])
.where('pairedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
.limit(1)
.get();

return snap.docs.isNotEmpty;
}

static Future<bool> _isReserveEligible(String uid) async {
final friends = await FriendsGraphService.getOnAppFriendsForUserUid(uid);
return friends.length >= 4;
}

static Future<MockPair> _buildNoFriendsPair({
required String key,
}) async {
final progress = await ProgressService.getUserProgress();
final points = (progress['points'] ?? 0) as int;
final currentStreak = (progress['currentStreak'] ?? 0) as int;
final longestStreak = (progress['longestStreak'] ?? 0) as int;
final lastCallAtMs = progress['lastCallAtMs'] as int?;

return MockPair(
dateKey: key,
hiddenName: 'Add more friends',
phone: '',
questionId: 'q0',
questionText: 'Add more people to unlock your daily call',
answerText: '',
callCompleted: false,
points: points,
currentStreak: currentStreak,
longestStreak: longestStreak,
lastCallAtMs: lastCallAtMs,
callIndex: 1,
totalCalls: 1,
partnerUid: null,
partnerUsername: null,
);
}

static String getTodayCallMetaLine() {
final pair = AppStorage.getTodayPair();
if (pair == null) return '';
return 'CALL 1 OF 1';
}

static Future<void> advanceAfterCompletion() async {
return;
}
}

enum _CandidateTier {
directOnApp,
friendOfFriend,
}

extension on _CandidateTier {
String get storageLabel {
switch (this) {
case _CandidateTier.directOnApp:
return 'direct_on_app';
case _CandidateTier.friendOfFriend:
return 'friend_of_friend';
}
}
}

class _MiniProfile {
final String displayName;
final String username;
final String phone;

const _MiniProfile({
required this.displayName,
required this.username,
required this.phone,
});
}