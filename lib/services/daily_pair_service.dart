// lib/services/daily_pair_service.dart
import 'dart:math' show Random, min, max;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';
import '../storage.dart';
import '../subscription.dart';
import 'progress_service.dart';
import 'firestore_service.dart';

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

  static String _dateKeyFromDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
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

  static String _pickAnswer({required Random rng, required int qIndex}) {
    final list = _answerBank[qIndex];
    if (list == null || list.isEmpty) return "…";
    return list[rng.nextInt(list.length)];
  }

  static String _fakePhoneForName(String name) {
    final n = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final last4 = (1000 + (n % 9000)).toString().padLeft(4, '0');
    return "+1 555-01$last4";
  }

  static int _totalCallsForToday({required int circleCount}) {
    if (!Subscription.isPlus()) return 1;
    return min(5, max(1, circleCount));
  }

  static Future<void> _resetIfNewKey(String key) async {
    final stored = AppStorage.getStoredTodayKey();
    if (stored == key) return;

    // ✅ new day => reset counters + clear current pair cache
    await AppStorage.setStoredTodayKey(key);
    await AppStorage.clearDailyCallState();
    await AppStorage.clearTodayPair();
  }

  static Future<void> ensureTodayPair() async {
    final key = effectiveKeyNowOrCallStart();
    await _resetIfNewKey(key);

    // If timer is running, keep current pair stable
    if (AppStorage.getCallStartedAt() != null) {
      final existing = AppStorage.getTodayPair();
      if (existing != null && existing.dateKey == key) return;
      // if local missing we will hydrate below
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = FirestoreService(uid);
    await db.ensureHasAtLeastOneCircle();

    final circles = await db.getCirclesOnce();
    if (circles.isEmpty) return;

    final totalCalls = _totalCallsForToday(circleCount: circles.length);

    var usedCircleIds = AppStorage.getUsedCircleIds();
    var callsUsed = AppStorage.getCallsUsedToday(); // completed calls

    final existing = AppStorage.getTodayPair();
    final hasLocalForKey = existing != null && existing.dateKey == key;

    // If we already have an active (not completed) pair, keep it.
    if (hasLocalForKey && existing!.callCompleted == false) return;

    // Free: if completed today, stop.
    if (!Subscription.isPlus() && hasLocalForKey && existing!.callCompleted == true) return;

    // Plus: if completed and no remaining calls, stop.
    if (Subscription.isPlus() && hasLocalForKey && existing!.callCompleted == true) {
      if (callsUsed >= totalCalls) return;
    }

    await ProgressService.ensureUserDoc();

    // 1) hydrate from Firestore if present
    final day = await ProgressService.getDay(key);
    if (day != null) {
      final hiddenName = (day['hiddenName'] ?? 'Mysto') as String;
      final questionId = (day['questionId'] ?? 'q0') as String;
      final callCompleted = (day['callCompleted'] ?? false) as bool;

      final questionText = (day['questionText'] ?? '') as String;
      final answerText = (day['answerText'] ?? '') as String;

      final storedPhone = (day['phone'] ?? '') as String;
      final phone = storedPhone.isNotEmpty ? storedPhone : _fakePhoneForName(hiddenName);

      final circleId = (day['circleId'] ?? '') as String;
      final circleName = (day['circleName'] ?? '') as String;
      final callIndex = (day['callIndex'] ?? 1) as int;
      final storedTotalCalls = (day['totalCalls'] ?? totalCalls) as int;

      // infer completed calls count from callIndex
      final inferredCompleted = callCompleted ? callIndex : max(0, callIndex - 1);
      if (callsUsed < inferredCompleted) {
        callsUsed = inferredCompleted;
        await AppStorage.setCallsUsedToday(callsUsed);
      }

      if (circleId.isNotEmpty && !usedCircleIds.contains(circleId)) {
        usedCircleIds = [...usedCircleIds, circleId];
        await AppStorage.setUsedCircleIds(usedCircleIds);
      }

      final progress = await ProgressService.getUserProgress();
      final points = (progress['points'] ?? 0) as int;
      final currentStreak = (progress['currentStreak'] ?? 0) as int;
      final longestStreak = (progress['longestStreak'] ?? 0) as int;
      final lastCallAtMs = progress['lastCallAtMs'] as int?;

      final pair = MockPair(
        dateKey: key,
        hiddenName: hiddenName,
        phone: phone,
        questionId: questionId,
        questionText: questionText,
        answerText: answerText,
        callCompleted: callCompleted,
        points: points,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        lastCallAtMs: lastCallAtMs,
        circleId: circleId,
        circleName: circleName,
        callIndex: callIndex,
        totalCalls: storedTotalCalls,
      );

      await AppStorage.setTodayPair(pair);

      // ✅ If this Firestore pair is still active, stop here.
      if (!callCompleted) return;

      // ✅ Free stops after completed.
      if (!Subscription.isPlus()) return;

      // ✅ Plus: if we still have calls left, continue and generate next call.
      if (callsUsed >= totalCalls) return;
      // else fall through to creation below
    }

    // 2) Create the next call for today (overwrite day doc)
    final rng = Random(DateTime.now().millisecondsSinceEpoch);

    List<UserCircle> candidateCircles = circles;
    if (Subscription.isPlus()) {
      candidateCircles = circles.where((c) => !usedCircleIds.contains(c.id)).toList();
      if (candidateCircles.isEmpty) candidateCircles = circles;
    }

    UserCircle? chosenCircle;
    List<CircleMember> chosenMembers = const <CircleMember>[];

    final shuffled = [...candidateCircles]..shuffle(rng);
    for (final c in shuffled) {
      final members = await db.getMembersOnce(c.id);
      if (members.isNotEmpty) {
        chosenCircle = c;
        chosenMembers = members;
        break;
      }
    }
    if (chosenCircle == null || chosenMembers.isEmpty) return;

    final pickMember = chosenMembers[rng.nextInt(chosenMembers.length)];
    final pickName = pickMember.displayName.trim().isEmpty ? "Mysto" : pickMember.displayName.trim();

    final qIndex = rng.nextInt(questions.length);
    final qId = "q$qIndex";
    final qText = questions[qIndex];
    final aText = _pickAnswer(rng: rng, qIndex: qIndex);
    final phone = _fakePhoneForName(pickName);

    final callIndex = min(totalCalls, callsUsed + 1);

    if (!usedCircleIds.contains(chosenCircle.id)) {
      usedCircleIds = [...usedCircleIds, chosenCircle.id];
      await AppStorage.setUsedCircleIds(usedCircleIds);
    }

    await ProgressService.setDay(key, {
      'dateKey': key,
      'hiddenName': pickName,
      'phone': phone,
      'questionId': qId,
      'questionText': qText,
      'answerText': aText,
      'callCompleted': false,
      'circleId': chosenCircle.id,
      'circleName': chosenCircle.name,
      'callIndex': callIndex,
      'totalCalls': totalCalls,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final progress = await ProgressService.getUserProgress();
    final points = (progress['points'] ?? 0) as int;
    final currentStreak = (progress['currentStreak'] ?? 0) as int;
    final longestStreak = (progress['longestStreak'] ?? 0) as int;
    final lastCallAtMs = progress['lastCallAtMs'] as int?;

    final newPair = MockPair(
      dateKey: key,
      hiddenName: pickName,
      phone: phone,
      questionId: qId,
      questionText: qText,
      answerText: aText,
      callCompleted: false,
      points: points,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastCallAtMs: lastCallAtMs,
      circleId: chosenCircle.id,
      circleName: chosenCircle.name,
      callIndex: callIndex,
      totalCalls: totalCalls,
    );

    await AppStorage.setTodayPair(newPair);
  }

  static String getTodayCallMetaLine() {
    final pair = AppStorage.getTodayPair();
    if (pair == null) return "";
    if (!Subscription.isPlus()) return "CALL 1 OF 1";
    return "CALL ${pair.callIndex} OF ${pair.totalCalls}";
  }

  static Future<void> advanceAfterCompletion() async {
    if (!Subscription.isPlus()) return;

    final used = AppStorage.getCallsUsedToday();
    await AppStorage.setCallsUsedToday(used + 1);

    await AppStorage.clearTodayPair();
    await ensureTodayPair();
  }
}
