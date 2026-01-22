// lib/screens/circle_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_router.dart';
import '../storage.dart';
import '../subscription.dart';
import '../theme/know_no_know_theme.dart';
import '../services/firestore_service.dart';

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  final TextEditingController _add = TextEditingController();
  String? _error;

  FirestoreService? _db;

  String? _selectedCircleId;

  static const int gateMinMembers = 7;
  static const int plusMaxCircles = 5;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _db = FirestoreService(uid);
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    // Ensure Circle 1 exists (and import legacy mystos into it once)
    await _db!.ensureHasAtLeastOneCircle();

    // Restore selected circle if we have it
    final saved = AppStorage.getSelectedCircleId();
    if (!mounted) return;
    setState(() => _selectedCircleId = saved);
  }

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  int get _maxCircles => Subscription.isPlus() ? plusMaxCircles : 1;

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "?";
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    final a = parts.first[0].toUpperCase();
    final b = parts.last[0].toUpperCase();
    return "$a$b";
  }

  Color _avatarBg(String name) {
    final h = name.hashCode.abs() % 6;
    switch (h) {
      case 0:
        return KnowNoKnowTheme.primary.withOpacity(0.14);
      case 1:
        return KnowNoKnowTheme.ink.withOpacity(0.10);
      case 2:
        return KnowNoKnowTheme.primary.withOpacity(0.20);
      case 3:
        return KnowNoKnowTheme.ink.withOpacity(0.06);
      case 4:
        return KnowNoKnowTheme.primary.withOpacity(0.10);
      default:
        return KnowNoKnowTheme.ink.withOpacity(0.08);
    }
  }

  Future<void> _selectCircle(String id) async {
    setState(() {
      _selectedCircleId = id;
      _error = null;
    });
    await AppStorage.setSelectedCircleId(id);
  }

  Future<void> _addMember(
    List<CircleMember> currentMembers,
    String circleId,
  ) async {
    final raw = _add.text.trim();
    if (raw.isEmpty) return;

    final exists = currentMembers.any(
      (m) => m.displayName.toLowerCase() == raw.toLowerCase(),
    );
    if (exists) {
      setState(() => _error = "Already in this circle.");
      return;
    }

    try {
      await _db!.addMember(circleId: circleId, displayName: raw, onKetchUp: false);
      setState(() {
        _error = null;
        _add.clear();
      });
    } catch (e) {
      setState(() => _error = "Couldn’t add. ($e)");
    }
  }

  Future<void> _removeMember(String circleId, String memberId) async {
    try {
      await _db!.removeMember(circleId: circleId, memberId: memberId);
    } catch (e) {
      setState(() => _error = "Couldn’t remove. ($e)");
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w800)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createNextCircle({
    required List<UserCircle> circles,
    required String selectedCircleId,
    required int selectedMemberCount,
  }) async {
    // FREE gate: only 1 circle
    if (!Subscription.isPlus()) {
      setState(() => _error = "Plus required to create more circles.");
      _toast("Unlock Plus to create up to 5 circles.");
      if (!mounted) return;
      Navigator.pushNamed(context, AppRouter.plus);
      return;
    }

    // Rule: can only create NEXT if you're on the LAST circle and it has >= 7 members
    final last = circles.isEmpty ? null : circles.last;
    if (last == null) return;

    final isOnLast = last.id == selectedCircleId;
    if (!isOnLast) {
      setState(() => _error = "Go to your last circle to unlock the next one.");
      return;
    }

    if (selectedMemberCount < gateMinMembers) {
      setState(() => _error = "Add $gateMinMembers people to unlock the next circle.");
      return;
    }

    if (circles.length >= _maxCircles) {
      setState(() => _error = "Max $_maxCircles circles.");
      return;
    }

    try {
      final newIndex = circles.length; // 0-based
      final newName = "Circle ${newIndex + 1}";
      final newId = await _db!.createCircle(name: newName, index: newIndex);
      await _selectCircle(newId);

      // Active circle list used by Today/DailyPairService
      await AppStorage.setCircle(<String>[]);
      if (!mounted) return;
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = "Couldn’t create circle. ($e)");
    }
  }

  Future<void> _syncActiveCircleToLocal(List<CircleMember> members) async {
    // Today/DailyPairService reads AppStorage.getCircle() to pick names.
    final names = members
        .map((m) => m.displayName.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await AppStorage.setCircle(names);
  }

  void _continueIfValid(List<CircleMember> members) {
    if (members.isEmpty) {
      setState(() => _error = "Add at least 1 person to start.");
      return;
    }
    Navigator.pushReplacementNamed(context, AppRouter.today);
  }

  @override
  Widget build(BuildContext context) {
    if (_db == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "CIRCLES",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: const Center(child: Text("Not signed in yet. Go back and sign in.")),
      );
    }

    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: KnowNoKnowTheme.ink,
          letterSpacing: -0.2,
        );

    final isPlus = Subscription.isPlus();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "CIRCLES",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
        ),
        actions: [
          IconButton(
            tooltip: "Settings",
            onPressed: () => Navigator.pushNamed(context, AppRouter.settings),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
        child: StreamBuilder<List<UserCircle>>(
          stream: _db!.streamCircles(),
          builder: (context, circlesSnap) {
            final circlesLoading = !circlesSnap.hasData;
            final allCircles = circlesSnap.data ?? const <UserCircle>[];

            if (circlesLoading) {
              return const SafeArea(child: Center(child: CircularProgressIndicator()));
            }

            if (allCircles.isEmpty) {
              // Shouldn't happen because ensureHasAtLeastOneCircle()
              return const SafeArea(child: Center(child: Text("Creating Circle 1…")));
            }

            // Enforce circle count in UI: Free sees only 1 circle.
            final circles = allCircles.take(_maxCircles).toList();

            // Pick selected circle (fallback to first visible circle)
            final fallbackId = circles.first.id;
            final selectedId =
                (_selectedCircleId != null && circles.any((c) => c.id == _selectedCircleId))
                    ? _selectedCircleId!
                    : fallbackId;

            if (_selectedCircleId != selectedId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _selectCircle(selectedId);
              });
            }

            final selectedCircle = circles.firstWhere((c) => c.id == selectedId);

            return StreamBuilder<List<CircleMember>>(
              stream: _db!.streamMembers(selectedId),
              builder: (context, membersSnap) {
                final membersLoading = !membersSnap.hasData;
                final members = membersSnap.data ?? const <CircleMember>[];

                if (membersSnap.hasData) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _syncActiveCircleToLocal(members);
                  });
                }

                final isLastCircle = circles.isNotEmpty && circles.last.id == selectedId;

                // Next-circle creation rules:
                // - must be Plus
                // - must be on last circle
                // - last circle must have >= 7 members
                // - circles < max
                final canUnlockNext = isPlus && isLastCircle && members.length >= gateMinMembers;
                final canCreateNext = canUnlockNext && circles.length < _maxCircles;

                final unlockText = !isPlus
                    ? "Free includes 1 circle. Unlock Plus to create up to 5."
                    : (isLastCircle
                        ? (members.length >= gateMinMembers
                            ? "Unlocked: you can create the next circle."
                            : "Add ${gateMinMembers - members.length} more to unlock Circle ${selectedCircle.index + 2}.")
                        : "Go to your last circle to unlock the next one.");

                final createButtonText = !isPlus
                    ? "UNLOCK PLUS FOR MORE CIRCLES"
                    : (circles.length >= _maxCircles
                        ? "MAX CIRCLES REACHED"
                        : (canCreateNext
                            ? "CREATE NEXT CIRCLE"
                            : "LOCKED • NEED $gateMinMembers IN LAST CIRCLE"));

                return SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                        child: Container(
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Your circles", style: titleStyle),
                              const SizedBox(height: 6),
                              Text(
                                isPlus
                                    ? "Unlimited people per circle. Unlock the next circle at $gateMinMembers people (max 5 circles)."
                                    : "Free includes 1 circle (unlimited people). Plus adds up to 5 circles.",
                                style: const TextStyle(
                                  color: KnowNoKnowTheme.mutedInk,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Circle tabs
                              SizedBox(
                                height: 44,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: circles.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (context, i) {
                                    final c = circles[i];
                                    final selected = c.id == selectedId;
                                    return GestureDetector(
                                      onTap: () => _selectCircle(c.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected ? KnowNoKnowTheme.ink : KnowNoKnowTheme.panel,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
                                        ),
                                        child: Text(
                                          c.name,
                                          style: TextStyle(
                                            color: selected ? KnowNoKnowTheme.white : KnowNoKnowTheme.ink,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Create next circle button (gated)
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    if (!isPlus) {
                                      setState(() => _error = "Plus required to create more circles.");
                                      Navigator.pushNamed(context, AppRouter.plus);
                                      return;
                                    }

                                    if (membersLoading) return;

                                    await _createNextCircle(
                                      circles: circles,
                                      selectedCircleId: selectedId,
                                      selectedMemberCount: members.length,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: KnowNoKnowTheme.ink,
                                    side: const BorderSide(color: KnowNoKnowTheme.stroke, width: 1.2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Text(
                                    createButtonText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),
                              Text(
                                unlockText,
                                style: const TextStyle(
                                  color: KnowNoKnowTheme.mutedInk,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Add member row (always allowed; unlimited size)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _add,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _addMember(members, selectedId),
                                      style: const TextStyle(
                                        color: KnowNoKnowTheme.ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Add a person to ${selectedCircle.name}…",
                                        hintStyle: const TextStyle(
                                          color: KnowNoKnowTheme.mutedInk,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        filled: true,
                                        fillColor: KnowNoKnowTheme.panel,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: const BorderSide(
                                            color: KnowNoKnowTheme.stroke,
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: const BorderSide(
                                            color: KnowNoKnowTheme.ink,
                                            width: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    height: 52,
                                    width: 56,
                                    child: ElevatedButton(
                                      onPressed: membersLoading ? null : () => _addMember(members, selectedId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: KnowNoKnowTheme.ink,
                                        foregroundColor: KnowNoKnowTheme.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: const Icon(Icons.add_rounded, size: 22),
                                    ),
                                  ),
                                ],
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: KnowNoKnowTheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                        child: Row(
                          children: [
                            _Pill(text: "${selectedCircle.name} • ${members.length} people"),
                            const SizedBox(width: 10),
                            const _Pill(text: "UNLIMITED SIZE", ghost: true),
                            const Spacer(),
                            _Pill(
                              text: isPlus ? "PLUS • ${circles.length}/$_maxCircles" : "FREE • 1/1",
                              ghost: true,
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: membersLoading
                            ? const Center(child: CircularProgressIndicator())
                            : members.isEmpty
                                ? const _EmptyMembers()
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                                    itemCount: members.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final m = members[i];
                                      final nm = m.displayName;
                                      return _MemberCell(
                                        name: nm,
                                        initials: _initials(nm),
                                        avatarBg: _avatarBg(nm),
                                        onRemove: () => _removeMember(selectedId, m.id),
                                        onKetchUp: m.onKetchUp,
                                      );
                                    },
                                  ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: () => _continueIfValid(members),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: KnowNoKnowTheme.ink,
                              foregroundColor: KnowNoKnowTheme.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              "DONE",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/* ---------------- UI bits ---------------- */

class _MemberCell extends StatelessWidget {
  const _MemberCell({
    required this.name,
    required this.initials,
    required this.avatarBg,
    required this.onRemove,
    required this.onKetchUp,
  });

  final String name;
  final String initials;
  final Color avatarBg;
  final VoidCallback onRemove;
  final bool onKetchUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: KnowNoKnowTheme.cardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: avatarBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: KnowNoKnowTheme.ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: KnowNoKnowTheme.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    onKetchUp ? "On KetchUp" : "Not on KetchUp yet",
                    style: const TextStyle(
                      color: KnowNoKnowTheme.mutedInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (onKetchUp)
              const _Tag(text: "ON", filled: true)
            else
              const _Tag(text: "SOON", filled: false),
            const SizedBox(width: 10),
            IconButton(
              tooltip: "Remove",
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              color: KnowNoKnowTheme.ink,
              style: IconButton.styleFrom(
                backgroundColor: KnowNoKnowTheme.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.filled});
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? KnowNoKnowTheme.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? KnowNoKnowTheme.white : KnowNoKnowTheme.ink,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.ghost = false});
  final String text;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ghost ? Colors.transparent : KnowNoKnowTheme.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: KnowNoKnowTheme.ink,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyMembers extends StatelessWidget {
  const _EmptyMembers();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: KnowNoKnowTheme.cardGradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "NO ONE IN THIS CIRCLE",
              style: TextStyle(
                color: KnowNoKnowTheme.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Add at least 1 person to start calling from this circle.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KnowNoKnowTheme.mutedInk,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
