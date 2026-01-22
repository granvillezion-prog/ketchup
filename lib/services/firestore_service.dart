// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService(this.uid);

  final String uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  // ✅ Circles live here
  CollectionReference<Map<String, dynamic>> get _circlesCol =>
      _userDoc.collection('circles');

  // ✅ Legacy (old system) — kept only for migration
  CollectionReference<Map<String, dynamic>> get _legacyMystosCol =>
      _userDoc.collection('mystos');

  // ------------------------------
  // CIRCLES (Streams)
  // ------------------------------

  Stream<List<UserCircle>> streamCircles() {
    return _circlesCol
        .orderBy('index', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(UserCircle.fromDoc).toList());
  }

  Stream<List<CircleMember>> streamMembers(String circleId) {
    return _circlesCol
        .doc(circleId)
        .collection('members')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CircleMember.fromDoc).toList());
  }

  // ------------------------------
  // CIRCLES (One-shot reads)
  // ------------------------------

  Future<List<UserCircle>> getCirclesOnce() async {
    final snap = await _circlesCol.orderBy('index', descending: false).get();
    return snap.docs.map(UserCircle.fromDoc).toList();
  }

  Future<List<CircleMember>> getMembersOnce(String circleId) async {
    final snap = await _circlesCol
        .doc(circleId)
        .collection('members')
        .orderBy('addedAt', descending: true)
        .get();
    return snap.docs.map(CircleMember.fromDoc).toList();
  }

  // ------------------------------
  // CIRCLE CRUD
  // ------------------------------

  Future<String> createCircle({
    required String name,
    required int index,
  }) async {
    final doc = _circlesCol.doc();
    await doc.set({
      'name': name,
      'index': index,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> renameCircle({
    required String circleId,
    required String name,
  }) async {
    await _circlesCol.doc(circleId).set(
      {
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteCircle(String circleId) async {
    // NOTE: Prototype simplicity: not recursively deleting members.
    // If you need it later, we can add a batched delete.
    await _circlesCol.doc(circleId).delete();
  }

  Future<void> addMember({
    required String circleId,
    required String displayName,
    bool onKetchUp = false,
  }) async {
    final memberId = "m_${DateTime.now().millisecondsSinceEpoch}";
    await _circlesCol.doc(circleId).collection('members').doc(memberId).set(
      {
        'displayName': displayName,
        'onKetchUp': onKetchUp,
        'addedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> removeMember({
    required String circleId,
    required String memberId,
  }) async {
    await _circlesCol.doc(circleId).collection('members').doc(memberId).delete();
  }

  // ------------------------------
  // BOOTSTRAP / MIGRATION:
  // - create Circle 1 if none exist
  // - import legacy mystos into Circle 1 once
  // ------------------------------

  Future<void> ensureHasAtLeastOneCircle() async {
    final circlesSnap = await _circlesCol.limit(1).get();
    if (circlesSnap.docs.isNotEmpty) return;

    // Create Circle 1
    final circle1Id = await createCircle(name: "Circle 1", index: 0);

    // Import legacy mystos into Circle 1 (if any)
    final legacy = await _legacyMystosCol.get();
    if (legacy.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final d in legacy.docs) {
      final data = d.data();
      final name = (data['displayName'] ?? '') as String;
      final onKetchUp = (data['onKetchUp'] ?? false) as bool;
      if (name.trim().isEmpty) continue;

      final memberRef =
          _circlesCol.doc(circle1Id).collection('members').doc("m_${d.id}");

      batch.set(
        memberRef,
        {
          'displayName': name.trim(),
          'onKetchUp': onKetchUp,
          'addedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    // We do NOT delete legacy docs automatically (safe).
  }

  // ------------------------------
  // LEGACY (only for migration / old UI paths)
  // ------------------------------

  Stream<List<Mysto>> streamMystos() {
    return _legacyMystosCol
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Mysto.fromDoc).toList());
  }

  Future<void> addMysto({
    required String mystoUid,
    required String displayName,
    bool onKetchUp = false,
  }) async {
    await _legacyMystosCol.doc(mystoUid).set(
      {
        'displayName': displayName,
        'onKetchUp': onKetchUp,
        'addedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> removeMysto(String mystoUid) async {
    await _legacyMystosCol.doc(mystoUid).delete();
  }
}

/* ---------------- Models ---------------- */

class UserCircle {
  UserCircle({
    required this.id,
    required this.name,
    required this.index,
  });

  final String id;
  final String name;
  final int index;

  factory UserCircle.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserCircle(
      id: doc.id,
      name: (data['name'] ?? 'Circle') as String,
      index: (data['index'] ?? 0) as int,
    );
  }
}

class CircleMember {
  CircleMember({
    required this.id,
    required this.displayName,
    required this.onKetchUp,
  });

  final String id;
  final String displayName;
  final bool onKetchUp;

  factory CircleMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CircleMember(
      id: doc.id,
      displayName: (data['displayName'] ?? '') as String,
      onKetchUp: (data['onKetchUp'] ?? false) as bool,
    );
  }
}

// Legacy model (kept to avoid breaking old code paths)
class Mysto {
  Mysto({
    required this.uid,
    required this.displayName,
    required this.onKetchUp,
    required this.addedAt,
  });

  final String uid;
  final String displayName;
  final bool onKetchUp;
  final DateTime? addedAt;

  factory Mysto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['addedAt'];
    return Mysto(
      uid: doc.id,
      displayName: (data['displayName'] ?? '') as String,
      onKetchUp: (data['onKetchUp'] ?? false) as bool,
      addedAt: (ts is Timestamp) ? ts.toDate() : null,
    );
  }
}
