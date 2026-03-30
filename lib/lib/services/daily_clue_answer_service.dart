import 'package:cloud_firestore/cloud_firestore.dart';

class DailyClueAnswerService {
DailyClueAnswerService._();

static String _key(String v) {
final t = v.trim();
return t.isEmpty ? 'unknown' : t;
}

/// Write an answer from `fromUsername` to `toUsername` for a specific day.
static Future<void> sendAnswer({
required String dateKey,
required String fromUsername,
required String toUsername,
required String answerText,
required String questionId,
required String questionText,
}) async {
final from = _key(fromUsername);
final to = _key(toUsername);

final doc = FirebaseFirestore.instance
.collection('daily_clue_answers')
.doc(dateKey)
.collection('to')
.doc(to)
.collection('from')
.doc(from);

await doc.set({
'dateKey': dateKey,
'fromUsername': from,
'toUsername': to,
'answerText': answerText.trim(),
'questionId': questionId,
'questionText': questionText,
'sentAtMs': DateTime.now().millisecondsSinceEpoch,
}, SetOptions(merge: true));
}

/// Listen for the answer sent TO `toUsername` FROM `fromUsername` for `dateKey`.
/// (UI stays anonymous because we never display fromUsername.)
static Stream<Map<String, dynamic>?> listenAnswer({
required String dateKey,
required String toUsername,
required String fromUsername,
}) {
final to = _key(toUsername);
final from = _key(fromUsername);

final doc = FirebaseFirestore.instance
.collection('daily_clue_answers')
.doc(dateKey)
.collection('to')
.doc(to)
.collection('from')
.doc(from);

return doc.snapshots().map((snap) => snap.data());
}
}