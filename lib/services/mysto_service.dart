import 'package:cloud_firestore/cloud_firestore.dart';

class MystoService {
  MystoService(this.uid);
  final String uid;

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _mystos =>
      _db.collection('users').doc(uid).collection('mystos');

  /// Returns a random mysto UID (or null)
  Future<String?> pickRandomMystoUid() async {
    final snap = await _mystos.get();
    if (snap.docs.isEmpty) return null;

    snap.docs.shuffle();
    return snap.docs.first.id;
  }

  Future<String?> getMystoName(String mystoUid) async {
    final snap = await _db.collection('users').doc(mystoUid).get();
    final data = snap.data();
    return data?['name'] as String?;
  }
}
