import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/know_no_know_theme.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _db = FirebaseFirestore.instance;
  final _q = TextEditingController();

  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _foundUser; // {uid, displayName, username}
  bool _sending = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _normalize(String s) => s.trim().toLowerCase().replaceAll('@', '');

  Future<void> _search() async {
    if (_loading) return;
    final username = _normalize(_q.text);

    setState(() {
      _error = null;
      _foundUser = null;
    });

    if (username.isEmpty) return;

    setState(() => _loading = true);

    try {
      final usernameDoc = await _db.collection('usernames').doc(username).get();
      if (!usernameDoc.exists) {
        setState(() => _error = "No user found for @$username");
        return;
      }

      final targetUid = (usernameDoc.data()?['uid'] ?? '') as String;
      if (targetUid.isEmpty) {
        setState(() => _error = "No user found for @$username");
        return;
      }

      if (targetUid == AuthService.uid) {
        setState(() => _error = "That’s you.");
        return;
      }

      final userDoc = await _db.collection('users').doc(targetUid).get();
      if (!userDoc.exists) {
        setState(() => _error = "No user found for @$username");
        return;
      }

      final data = userDoc.data() ?? <String, dynamic>{};

      setState(() {
        _foundUser = {
          'uid': targetUid,
          'displayName': (data['displayName'] ?? 'Unknown') as String,
          'username': username,
        };
      });
    } catch (e) {
      setState(() => _error = "Search failed. ($e)");
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest() async {
    if (_sending) return;
    final found = _foundUser;
    if (found == null) return;

    final fromUid = AuthService.uid;
    final toUid = (found['uid'] ?? '') as String;
    if (toUid.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      // outgoing for me
      await _db
          .collection('users')
          .doc(fromUid)
          .collection('outgoing_requests')
          .doc(toUid)
          .set({
        'toUid': toUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // incoming for them
      await _db
          .collection('users')
          .doc(toUid)
          .collection('friend_requests')
          .doc(fromUid)
          .set({
        'fromUid': fromUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Friend request sent."),
          duration: Duration(milliseconds: 900),
        ),
      );

      setState(() {
        _foundUser = null;
        _q.clear();
      });
    } catch (e) {
      setState(() => _error = "Couldn’t send request. ($e)");
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = _foundUser;
    final showCard = found != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "ADD FRIEND",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/today_screen.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Search by username",
                  style: TextStyle(
                    color: KnowNoKnowTheme.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "You’ll only see @usernames here.\nIn your friends list, you’ll only see real names.",
                  style: TextStyle(
                    color: KnowNoKnowTheme.mutedInk,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),

                // Search bar card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: KnowNoKnowTheme.cardGradient,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _q,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          style: const TextStyle(
                            color: KnowNoKnowTheme.ink,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            prefixText: "@",
                            hintText: "zion",
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        width: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _search,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KnowNoKnowTheme.ink,
                            foregroundColor: KnowNoKnowTheme.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search_rounded),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: KnowNoKnowTheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                if (showCard) ...[
                  // Profile preview card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: KnowNoKnowTheme.cardGradient,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.black.withOpacity(0.10),
                          child: Text(
                            (found['displayName'] as String).isNotEmpty
                                ? (found['displayName'] as String)[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                found['displayName'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: KnowNoKnowTheme.ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "@${found['username']}",
                                style: const TextStyle(
                                  color: KnowNoKnowTheme.mutedInk,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.black),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _sendRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KnowNoKnowTheme.ink,
                        foregroundColor: KnowNoKnowTheme.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _sending ? "SENDING..." : "SEND FRIEND REQUEST",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Bottom explainer card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE353FE),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
                  ),
                  child: const Text(
                    "Why usernames?\nSo no duplicates. Your friends still see your REAL name everywhere else.",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
