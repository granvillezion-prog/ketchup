import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
static final _db = FirebaseFirestore.instance;
static final _auth = FirebaseAuth.instance;

static String _uidOrThrow() {
final uid = _auth.currentUser?.uid;
if (uid == null) throw Exception("No user signed in.");
return uid;
}

static DocumentReference<Map<String, dynamic>> _userDoc() {
final uid = _uidOrThrow();
return _db.collection('users').doc(uid);
}

static CollectionReference<Map<String, dynamic>> _daysCol() {
return _userDoc().collection('days');
}

static String dateKeyFor(DateTime dt) {
final y = dt.year.toString().padLeft(4, '0');
final m = dt.month.toString().padLeft(2, '0');
final d = dt.day.toString().padLeft(2, '0');
return '$y-$m-$d';
}

static String todayKey() => dateKeyFor(DateTime.now());

static String yesterdayKey() =>
dateKeyFor(DateTime.now().subtract(const Duration(days: 1)));

static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

static int? _asInt(dynamic raw) {
if (raw is int) return raw;
if (raw is num) return raw.toInt();
return null;
}

/// Ensures /users/{uid} exists and required retention fields exist.
static Future<void> ensureUserDoc() async {
final ref = _userDoc();
final snap = await ref.get();

final nowMs = _nowMs();

final base = <String, dynamic>{
'points': 0,
'currentStreak': 0,
'longestStreak': 0,
'lastCallAtMs': null,
'lastCompletedCallAtMs': null,
'lastActiveAtMs': nowMs,
'createdAt': FieldValue.serverTimestamp(),
'updatedAt': FieldValue.serverTimestamp(),
};

if (!snap.exists) {
await ref.set(base, SetOptions(merge: true));
return;
}

final data = snap.data() ?? <String, dynamic>{};

await ref.set(
{
'updatedAt': FieldValue.serverTimestamp(),
if (!data.containsKey('points')) 'points': 0,
if (!data.containsKey('currentStreak')) 'currentStreak': 0,
if (!data.containsKey('longestStreak')) 'longestStreak': 0,
if (!data.containsKey('lastCallAtMs')) 'lastCallAtMs': null,
if (!data.containsKey('lastCompletedCallAtMs'))
'lastCompletedCallAtMs': null,
if (!data.containsKey('lastActiveAtMs')) 'lastActiveAtMs': nowMs,
},
SetOptions(merge: true),
);
}

/// Reads /users/{uid}
static Future<Map<String, dynamic>> getUserProgress() async {
final snap = await _userDoc().get();
return snap.data() ?? <String, dynamic>{};
}

/// Writes /users/{uid} (merge)
static Future<void> setUserProgress(Map<String, dynamic> data) async {
await _userDoc().set(
{
...data,
'updatedAt': FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
);
}

/// App-open / screen-open activity heartbeat.
static Future<void> touchActiveNow() async {
final nowMs = _nowMs();
await _userDoc().set(
{
'lastActiveAtMs': nowMs,
'updatedAt': FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
);
}

/// Call-complete truth for retention logic.
static Future<void> markCallCompletedNow() async {
final nowMs = _nowMs();
await _userDoc().set(
{
'lastActiveAtMs': nowMs,
'lastCallAtMs': nowMs,
'lastCompletedCallAtMs': nowMs,
'updatedAt': FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
);
}

static Future<int?> getLastActiveAtMs() async {
final data = await getUserProgress();
return _asInt(data['lastActiveAtMs']);
}

static Future<int?> getLastCompletedCallAtMs() async {
final data = await getUserProgress();
return _asInt(data['lastCompletedCallAtMs']);
}

/// Used by matching eligibility.
static Future<bool> isRecentlyActive({
int maxInactiveDays = 3,
}) async {
final lastActiveAtMs = await getLastActiveAtMs();
if (lastActiveAtMs == null) return false;

final nowMs = _nowMs();
final cutoffMs = Duration(days: maxInactiveDays).inMilliseconds;

return (nowMs - lastActiveAtMs) <= cutoffMs;
}

/// Reads /users/{uid}/days/{dateKey}
static Future<Map<String, dynamic>?> getDay(String dateKey) async {
final snap = await _daysCol().doc(dateKey).get();
if (!snap.exists) return null;
return snap.data();
}

static Future<bool> didCompleteDay(String dateKey) async {
final day = await getDay(dateKey);
if (day == null) return false;
return (day['callCompleted'] ?? false) == true;
}

static Future<bool> wasDayMissed(String dateKey) async {
final day = await getDay(dateKey);
if (day == null) return false;

final hiddenName = (day['hiddenName'] ?? '').toString().trim();
final completed = (day['callCompleted'] ?? false) == true;

if (hiddenName.isEmpty) return false;
if (hiddenName == 'Add more friends') return false;
if (completed) return false;

return true;
}

static Future<bool> wasYesterdayMissed() async {
return wasDayMissed(yesterdayKey());
}

/// Writes /users/{uid}/days/{dateKey} (merge)
static Future<void> setDay(String dateKey, Map<String, dynamic> data) async {
final merged = <String, dynamic>{
...data,
'dateKey': dateKey,
'updatedAt': FieldValue.serverTimestamp(),
};

await _daysCol().doc(dateKey).set(merged, SetOptions(merge: true));
}
}