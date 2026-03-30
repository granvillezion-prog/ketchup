import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'storage.dart';
import 'services/daily_pair_service.dart';
import 'services/friends_graph_service.dart';
import 'services/progress_service.dart';

class AppState {
// ------------------------------------------------------------
// CONFIG
// ------------------------------------------------------------

static const int baseCallSeconds = 300; // 5 min
static const int extensionSeconds = 300;

static const String _answersCol = 'daily_answers';

// local extension tracking
static bool _extendedOnce = false;

// ------------------------------------------------------------
// QUESTIONS
// ------------------------------------------------------------

static const List<MockQuestion> _questions = [
MockQuestion(
id: 'q1',
text: 'What’s something you’re excited about right now?',
),
MockQuestion(
id: 'q2',
text: 'What’s been weighing on you lately?',
),
MockQuestion(
id: 'q3',
text: 'What’s one win from this week?',
),
MockQuestion(
id: 'q4',
text: 'What’s a memory you still laugh about?',
),
MockQuestion(
id: 'q5',
text: 'If you could redo one decision, what would it be?',
),
];

static MockQuestion getQuestionById(String id) {
return _questions.firstWhere(
(q) => q.id == id,
orElse: () => _questions.first,
);
}

static String _todayKey() {
final now = DateTime.now();
return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

static String _yesterdayKey() {
final now = DateTime.now().subtract(const Duration(days: 1));
return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

static bool _isSameDay(MockPair p) => p.dateKey == _todayKey();

// ------------------------------------------------------------
// PAIR LOGIC
// ------------------------------------------------------------

static Future<MockPair?> ensureTodayPair() async {
final today = _todayKey();

final existing = AppStorage.getTodayPair();
if (existing != null && existing.dateKey == today) return existing;

final circle = AppStorage.getCircle();
if (circle.isEmpty) return null;

final hasRealPool = await FriendsGraphService.hasValidMatchPool(min: 1);

if (!hasRealPool) {
final fallback = _buildNoRealMatchesPair(today);
await AppStorage.setTodayPair(fallback);
await clearCallStarted();
return fallback;
}

await DailyPairService.ensureTodayPair();

final realPair = AppStorage.getTodayPair();
if (realPair != null && realPair.dateKey == today) return realPair;

final fallback = _buildNoRealMatchesPair(today);
await AppStorage.setTodayPair(fallback);
await clearCallStarted();
return fallback;
}

static MockPair _buildNoRealMatchesPair(String today) {
final q = _questions.first;

return MockPair(
dateKey: today,
hiddenName: 'Add more friends',
phone: '',
questionId: q.id,
questionText: q.text,
answerText: '',
myAnswerText: '',
callCompleted: false,
points: 0,
currentStreak: 0,
longestStreak: 0,
lastCallAtMs: null,
circleId: '',
circleName: 'unmatched_priority_tomorrow',
callIndex: 1,
totalCalls: 1,
);
}

// ------------------------------------------------------------
// CALL CONTROL
// ------------------------------------------------------------

static bool isCallActive() {
final started = AppStorage.getCallStartedAt();
final total = AppStorage.getCallTotalSeconds();
return started != null && total != null;
}

static Future<bool> tryStartCall() async {
if (isCallActive()) return false;

final now = DateTime.now().millisecondsSinceEpoch;

await AppStorage.setCallStartedAt(now);
await AppStorage.setCallTotalSeconds(baseCallSeconds);

_extendedOnce = false;
return true;
}

static int? getRemainingCallSeconds() {
final startedAt = AppStorage.getCallStartedAt();
final total = AppStorage.getCallTotalSeconds();

if (startedAt == null || total == null) return null;

final now = DateTime.now().millisecondsSinceEpoch;
final elapsed = ((now - startedAt) / 1000).floor();

final rem = total - elapsed;
if (rem <= 0) return 0;
return rem;
}

static Future<bool> extendCallOnce() async {
if (_extendedOnce) return false;

final total = AppStorage.getCallTotalSeconds();
if (total == null) return false;

await AppStorage.setCallTotalSeconds(total + extensionSeconds);
_extendedOnce = true;
return true;
}

static Future<void> clearCallStarted() async {
await AppStorage.clearCallTimer();
_extendedOnce = false;
}

// ------------------------------------------------------------
// STREAK LOSS
// ------------------------------------------------------------

static Future<void> enforceStreakLossIfNeeded() async {
await ProgressService.ensureUserDoc();

final progress = await ProgressService.getUserProgress();
final lastCompletedCallAtMs = progress['lastCompletedCallAtMs'];

int? lastMs;
if (lastCompletedCallAtMs is int) {
lastMs = lastCompletedCallAtMs;
} else if (lastCompletedCallAtMs is num) {
lastMs = lastCompletedCallAtMs.toInt();
}

if (lastMs == null) return;

final lastCompletedKey = ProgressService.dateKeyFor(
DateTime.fromMillisecondsSinceEpoch(lastMs),
);

final today = _todayKey();
final yesterday = _yesterdayKey();

if (lastCompletedKey == today || lastCompletedKey == yesterday) {
return;
}

final currentStreak = (progress['currentStreak'] ?? 0) as int;
if (currentStreak == 0) return;

await ProgressService.setUserProgress({
'currentStreak': 0,
});
}

// ------------------------------------------------------------
// CALL COMPLETE / DAILY STREAK
// ------------------------------------------------------------

static Future<void> markCallComplete() async {
final pair = AppStorage.getTodayPair();
if (pair == null) return;

if (!_isSameDay(pair)) {
await ensureTodayPair();
await clearCallStarted();
return;
}

await enforceStreakLossIfNeeded();

if (pair.callCompleted) {
await clearCallStarted();
return;
}

final now = DateTime.now().millisecondsSinceEpoch;
final today = _todayKey();
final yesterday = _yesterdayKey();

final progress = await ProgressService.getUserProgress();

final oldPoints = (progress['points'] ?? pair.points) as int;
final oldCurrentStreak =
(progress['currentStreak'] ?? pair.currentStreak) as int;
final oldLongestStreak =
(progress['longestStreak'] ?? pair.longestStreak) as int;

final rawLastCompleted = progress['lastCompletedCallAtMs'];

int? lastCompletedMs;
if (rawLastCompleted is int) {
lastCompletedMs = rawLastCompleted;
} else if (rawLastCompleted is num) {
lastCompletedMs = rawLastCompleted.toInt();
}

final completedToday = lastCompletedMs != null &&
ProgressService.dateKeyFor(
DateTime.fromMillisecondsSinceEpoch(lastCompletedMs),
) ==
today;

final int nextPoints;
final int nextCurrentStreak;
final int nextLongestStreak;

if (completedToday) {
nextPoints = oldPoints;
nextCurrentStreak = oldCurrentStreak;
nextLongestStreak = oldLongestStreak;
} else {
final completedYesterday = lastCompletedMs != null &&
ProgressService.dateKeyFor(
DateTime.fromMillisecondsSinceEpoch(lastCompletedMs),
) ==
yesterday;

nextPoints = oldPoints + 1;
nextCurrentStreak = completedYesterday ? oldCurrentStreak + 1 : 1;
nextLongestStreak = math.max(oldLongestStreak, nextCurrentStreak);
}

final updated = pair.copyWith(
callCompleted: true,
lastCallAtMs: now,
points: nextPoints,
currentStreak: nextCurrentStreak,
longestStreak: nextLongestStreak,
);

await AppStorage.setTodayPair(updated);

await ProgressService.markCallCompletedNow();

await ProgressService.setUserProgress({
'points': nextPoints,
'currentStreak': nextCurrentStreak,
'longestStreak': nextLongestStreak,
'lastCallAtMs': now,
'lastCompletedCallAtMs': now,
'lastActiveAtMs': now,
});

final existingDay =
await ProgressService.getDay(today) ?? <String, dynamic>{};

await ProgressService.setDay(today, {
...existingDay,
'hiddenName': updated.hiddenName,
'phone': updated.phone,
'questionId': updated.questionId,
'questionText': updated.questionText,
'answerText': updated.answerText,
'myAnswerText': updated.myAnswerText,
'callCompleted': true,
'completedAtMs': now,
'lastCallAtMs': now,
'points': nextPoints,
'currentStreak': nextCurrentStreak,
'longestStreak': nextLongestStreak,
'circleId': updated.circleId,
'circleName': updated.circleName,
'callIndex': updated.callIndex,
'totalCalls': updated.totalCalls,
});

await clearCallStarted();
}

// ------------------------------------------------------------
// ANSWERS
// ------------------------------------------------------------

static String _sanitizeAnswer(String raw) {
final t = raw.trim();
if (t.isEmpty) return '';
return t.length > 140 ? t.substring(0, 140) : t;
}

static Future<MockPair?> sendMyAnswerAnonymous(String raw) async {
final ensured = await ensureTodayPair();
if (ensured == null) return null;

final text = _sanitizeAnswer(raw);
if (text.isEmpty) return ensured;

final myUsername = AppStorage.getProfileUsername().trim();
final recipientUsername = ensured.hiddenName.trim();

if (myUsername.isEmpty || recipientUsername.isEmpty) return ensured;

final updated = ensured.copyWith(myAnswerText: text);
await AppStorage.setTodayPair(updated);

final today = _todayKey();
final rand = math.Random().nextInt(1 << 32).toString();

await FirebaseFirestore.instance
.collection(_answersCol)
.doc('${today}__${recipientUsername}__${rand}')
.set({
'dateKey': today,
'recipient': recipientUsername,
'answerText': text,
'createdAt': FieldValue.serverTimestamp(),
});

return updated;
}

static Future<MockPair?> pollIncomingAnonymousAnswer() async {
final pair = await ensureTodayPair();
if (pair == null) return null;

final myUsername = AppStorage.getProfileUsername().trim();
if (myUsername.isEmpty) return pair;

final today = _todayKey();

try {
final qs = await FirebaseFirestore.instance
.collection(_answersCol)
.where('dateKey', isEqualTo: today)
.where('recipient', isEqualTo: myUsername)
.orderBy('createdAt', descending: true)
.limit(1)
.get();

if (qs.docs.isEmpty) return pair;

final incoming = (qs.docs.first.data()['answerText'] ?? '').toString();
if (incoming.isEmpty) return pair;

final updated = pair.copyWith(answerText: incoming);
await AppStorage.setTodayPair(updated);

return updated;
} catch (_) {
return pair;
}
}
}