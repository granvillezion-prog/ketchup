// lib/services/firestore_service.dart
export '../models.dart' show CircleMember;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart' show CircleMember;

class FirestoreService {
  FirestoreService(this.uid);

  final String uid;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _publicProfilesCol =>
      _db.collection('publicProfiles');

  DocumentReference<Map<String, dynamic>> get _publicProfileDoc =>
      _publicProfilesCol.doc(uid);

  CollectionReference<Map<String, dynamic>> get _circlesCol =>
      _userDoc.collection('circles');

  CollectionReference<Map<String, dynamic>> get _legacyMystosCol =>
      _userDoc.collection('mystos');

  CollectionReference<Map<String, dynamic>> get _usernamesCol =>
      _db.collection('usernames');

  CollectionReference<Map<String, dynamic>> get _phonesCol =>
      _db.collection('phones');

  static String normalizeUsername(String raw) {
    return raw.trim().toLowerCase();
  }

  static String normalizePhone(String raw) {
    final digits = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return '+$digits';
  }

  static String _cleanToken(String s) {
    final lowered = s.trim().toLowerCase();
    final cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> buildSearchTokens({
    required String displayName,
    required String username,
  }) {
    final dn = _cleanToken(displayName);
    final un = _cleanToken(username);

    final base = <String>[];
    if (dn.isNotEmpty) base.add(dn);
    if (un.isNotEmpty) base.add(un);

    final words = <String>[
      ...dn.split(' ').where((w) => w.isNotEmpty),
      ...un.split(' ').where((w) => w.isNotEmpty),
    ];

    if (dn.isNotEmpty) base.add(dn.replaceAll(' ', ''));
    if (un.isNotEmpty) base.add(un.replaceAll(' ', ''));

    final set = <String>{};

    void addWithPrefixes(String w) {
      final t = w.trim();
      if (t.isEmpty) return;

      set.add(t);

      final max = t.length < 10 ? t.length : 10;
      for (var i = 2; i <= max; i++) {
        set.add(t.substring(0, i));
      }
    }

    for (final b in base) {
      addWithPrefixes(b);
    }
    for (final w in words) {
      addWithPrefixes(w);
    }

    final out = set.toList()..sort((a, b) => a.length.compareTo(b.length));
    const cap = 80;
    if (out.length > cap) return out.sublist(0, cap);
    return out;
  }

  Future<void> setDisplayName({
    required String displayName,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) return;

    final snap = await _userDoc.get();
    final data = snap.data() ?? <String, dynamic>{};
    final usernameLower = ((data['usernameLower'] ?? '') as String).trim();

    final displayLower = name.toLowerCase();
    final tokens = buildSearchTokens(
      displayName: name,
      username: usernameLower,
    );

    final payload = <String, dynamic>{
      'displayName': name,
      'displayNameLower': displayLower,
      'searchTokens': tokens,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _userDoc.set(payload, SetOptions(merge: true));
    await _publicProfileDoc.set(payload, SetOptions(merge: true));

    if (usernameLower.isNotEmpty) {
      await _usernamesCol.doc(usernameLower).set(
        {
          'displayName': name,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<void> claimUsername({
    required String usernameRaw,
    required String displayName,
  }) async {
    final u = normalizeUsername(usernameRaw);
    if (u.isEmpty) throw StateError("Pick a username.");

    final usernameRef = _usernamesCol.doc(u);
    final userRef = _userDoc;
    final publicRef = _publicProfileDoc;

    final displayLower = displayName.trim().toLowerCase();
    final searchTokens = buildSearchTokens(
      displayName: displayName,
      username: u,
    );

    await _db.runTransaction((tx) async {
      final regSnap = await tx.get(usernameRef);

      if (regSnap.exists) {
        final data = regSnap.data() ?? <String, dynamic>{};
        final existingUid = (data['uid'] ?? '') as String;
        if (existingUid.isNotEmpty && existingUid != uid) {
          throw StateError("That username is taken.");
        }
      }

      tx.set(
        usernameRef,
        {
          'uid': uid,
          'displayName': displayName,
          'username': u,
          'usernameLower': u,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        userRef,
        {
          'displayName': displayName,
          'displayNameLower': displayLower,
          'username': u,
          'usernameLower': u,
          'searchTokens': searchTokens,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        publicRef,
        {
          'displayName': displayName,
          'displayNameLower': displayLower,
          'username': u,
          'usernameLower': u,
          'searchTokens': searchTokens,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> updateProfilePhoto({
    required String photoUrl,
  }) async {
    final url = photoUrl.trim();
    if (url.isEmpty) return;

    final snap = await _userDoc.get();
    final usernameLower =
        ((snap.data() ?? <String, dynamic>{})['usernameLower'] ?? '') as String;

    final payload = <String, dynamic>{
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _userDoc.set(payload, SetOptions(merge: true));
    await _publicProfileDoc.set(payload, SetOptions(merge: true));

    final uname = usernameLower.trim();
    if (uname.isNotEmpty) {
      await _usernamesCol.doc(uname).set(
        payload,
        SetOptions(merge: true),
      );
    }
  }

  Future<void> updatePublicProfileSearchIndex({
    required String displayName,
    required String username,
  }) async {
    final displayLower = displayName.trim().toLowerCase();
    final unameLower = normalizeUsername(username);
    final tokens = buildSearchTokens(
      displayName: displayName,
      username: unameLower,
    );

    await _publicProfileDoc.set(
      {
        'displayName': displayName,
        'displayNameLower': displayLower,
        'username': unameLower,
        'usernameLower': unameLower,
        'searchTokens': tokens,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _userDoc.set(
      {
        'displayName': displayName,
        'displayNameLower': displayLower,
        'username': unameLower,
        'usernameLower': unameLower,
        'searchTokens': tokens,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String?> getUidByUsername(String rawUsername) async {
    final u = normalizeUsername(rawUsername);
    if (u.isEmpty) return null;

    final reg = await _usernamesCol.doc(u).get();
    if (!reg.exists) return null;

    final data = reg.data() ?? <String, dynamic>{};
    final found = (data['uid'] ?? '') as String;
    return found.isEmpty ? null : found;
  }

  Future<PublicProfile?> getPublicProfile(String otherUid) async {
    final pubSnap = await _publicProfilesCol.doc(otherUid).get();
    if (pubSnap.exists) {
      final data = pubSnap.data() ?? <String, dynamic>{};
      return PublicProfile(
        uid: otherUid,
        displayName: (data['displayName'] ?? '') as String,
        username: (data['username'] ?? '') as String,
        phoneE164: (data['phoneE164'] ?? '') as String,
        photoUrl: (data['photoUrl'] ?? '') as String,
      );
    }

    final userSnap = await _db.collection('users').doc(otherUid).get();
    if (!userSnap.exists) return null;

    final data = userSnap.data() ?? <String, dynamic>{};
    return PublicProfile(
      uid: otherUid,
      displayName: (data['displayName'] ?? '') as String,
      username: (data['username'] ?? '') as String,
      phoneE164: (data['phoneE164'] ?? '') as String,
      photoUrl: (data['photoUrl'] ?? '') as String,
    );
  }

  Future<List<PublicProfile>> getPublicProfilesByUids(List<String> uids) async {
    final cleaned =
        uids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (cleaned.isEmpty) return [];

    const chunkSize = 10;
    final out = <PublicProfile>[];
    final found = <String>{};

    for (var i = 0; i < cleaned.length; i += chunkSize) {
      final chunk =
          cleaned.sublist(i, (i + chunkSize).clamp(0, cleaned.length));
      final qs = await _publicProfilesCol
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final d in qs.docs) {
        final data = d.data();
        found.add(d.id);
        out.add(
          PublicProfile(
            uid: d.id,
            displayName: (data['displayName'] ?? '') as String,
            username: (data['username'] ?? '') as String,
            phoneE164: (data['phoneE164'] ?? '') as String,
            photoUrl: (data['photoUrl'] ?? '') as String,
          ),
        );
      }
    }

    final missing = cleaned.where((id) => !found.contains(id)).toList();
    for (var i = 0; i < missing.length; i += chunkSize) {
      final chunk =
          missing.sublist(i, (i + chunkSize).clamp(0, missing.length));

      final qs = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final d in qs.docs) {
        final data = d.data();
        out.add(
          PublicProfile(
            uid: d.id,
            displayName: (data['displayName'] ?? '') as String,
            username: (data['username'] ?? '') as String,
            phoneE164: (data['phoneE164'] ?? '') as String,
            photoUrl: (data['photoUrl'] ?? '') as String,
          ),
        );
      }
    }

    return out;
  }

  Future<void> claimPhone({
    required String phoneE164Raw,
  }) async {
    final p = normalizePhone(phoneE164Raw);
    if (p.isEmpty) throw StateError("Enter a valid phone number.");

    final phoneRef = _phonesCol.doc(p);
    final userRef = _userDoc;
    final publicRef = _publicProfileDoc;

    await _db.runTransaction((tx) async {
      final regSnap = await tx.get(phoneRef);

      if (regSnap.exists) {
        final data = regSnap.data() ?? <String, dynamic>{};
        final existingUid = (data['uid'] ?? '') as String;

        if (existingUid.isNotEmpty && existingUid != uid) {
          throw StateError("That phone number is already in use.");
        }
      }

      tx.set(
        phoneRef,
        {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        userRef,
        {
          'phoneE164': p,
          'phoneVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        publicRef,
        {
          'phoneE164': p,
          'phoneVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<Map<String, String>> lookupExistingUsersByPhones(
    List<String> phones,
  ) async {
    final normalized = phones
        .map(normalizePhone)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    if (normalized.isEmpty) return {};

    const chunkSize = 10;
    final out = <String, String>{};

    for (var i = 0; i < normalized.length; i += chunkSize) {
      final chunk =
          normalized.sublist(i, (i + chunkSize).clamp(0, normalized.length));

      final qs =
          await _phonesCol.where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in qs.docs) {
        final data = d.data();
        final foundUid = (data['uid'] ?? '') as String;
        if (foundUid.isEmpty) continue;
        out[d.id] = foundUid;
      }
    }

    return out;
  }

  Future<String> ensureDefaultCircleId() async {
    await ensureHasAtLeastOneCircle();
    final snap =
        await _circlesCol.orderBy('index', descending: false).limit(1).get();

    if (snap.docs.isEmpty) {
      final id = await createCircle(name: "Circle 1", index: 0);
      return id;
    }

    return snap.docs.first.id;
  }

  Future<void> addMembersBulk({
    required String circleId,
    required List<CircleSeedMember> members,
  }) async {
    if (members.isEmpty) return;

    final col = _circlesCol.doc(circleId).collection('members');
    final batch = _db.batch();

    for (final m in members) {
      var id = m.memberId.trim();
      if (id.isEmpty) {
        id =
            "m_${DateTime.now().millisecondsSinceEpoch}_${m.displayName.hashCode}";
      }

      final ref = col.doc(id);

      final cleanedUid = (m.uid ?? '').trim();
      final cleanedName = m.displayName.trim();
      final cleanedUsername = (m.username ?? '').trim();
      final cleanedPhone = (m.phoneE164 ?? '').trim();
      final isRealUser = cleanedUid.isNotEmpty;

      if (cleanedName.isEmpty) continue;

      batch.set(
        ref,
        {
          'memberId': id,
          'uid': isRealUser ? cleanedUid : null,
          'displayName': cleanedName,
          'username': cleanedUsername,
          'phoneE164': cleanedPhone,
          'onKetchUp': isRealUser,
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

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
    await _circlesCol.doc(circleId).delete();
  }

  Future<void> addMember({
    required String circleId,
    required String displayName,
    bool onKetchUp = false,
  }) async {
    final cleanedName = displayName.trim();
    if (cleanedName.isEmpty) return;

    final memberId = "m_${DateTime.now().millisecondsSinceEpoch}";
    await _circlesCol.doc(circleId).collection('members').doc(memberId).set(
      {
        'memberId': memberId,
        'uid': null,
        'displayName': cleanedName,
        'username': '',
        'phoneE164': '',
        'onKetchUp': false,
        'addedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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

  Future<void> ensureHasAtLeastOneCircle() async {
    final circlesSnap = await _circlesCol.limit(1).get();
    if (circlesSnap.docs.isNotEmpty) return;

    final circle1Id = await createCircle(name: "Circle 1", index: 0);

    final legacy = await _legacyMystosCol.get();
    if (legacy.docs.isEmpty) return;

    final batch = _db.batch();

    for (final d in legacy.docs) {
      final data = d.data();
      final name = (data['displayName'] ?? '') as String;
      if (name.trim().isEmpty) continue;

      final memberRef =
          _circlesCol.doc(circle1Id).collection('members').doc("m_${d.id}");

      batch.set(
        memberRef,
        {
          'memberId': "m_${d.id}",
          'uid': null,
          'displayName': name.trim(),
          'username': '',
          'phoneE164': '',
          'onKetchUp': false,
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

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

class CircleSeedMember {
  CircleSeedMember({
    required this.memberId,
    required this.displayName,
    this.onKetchUp = false,
    this.uid,
    this.username,
    this.phoneE164,
  });

  final String memberId;
  final String displayName;
  final bool onKetchUp;
  final String? uid;
  final String? username;
  final String? phoneE164;
}

class PublicProfile {
  PublicProfile({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.phoneE164,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String username;
  final String phoneE164;
  final String? photoUrl;
}

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