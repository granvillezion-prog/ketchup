import 'package:flutter/material.dart';

import '../app_router.dart';
import '../storage.dart';

// If your theme file accidentally defines TodayScreen, hide it here to prevent name collision.
import '../theme/know_no_know_theme.dart' hide TodayScreen;
import '../theme/know_no_know_theme.dart';

import 'today_screen.dart';
import 'plus_paywall_screen.dart';
import 'profile_hub_screen.dart';
import 'circle_screen.dart';

class AppShell extends StatefulWidget {
  final int initialIndex; // 0=Home, 1=Friends, 3=Plus, 4=Profile
  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index;
  int _lastNonCallIndex = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
    _lastNonCallIndex = (_index == 2) ? 0 : _index;
  }

  void _setIndex(int i) {
    if (i == 2) {
      _handleCallTap();
      return;
    }

    setState(() {
      _index = i;
      _lastNonCallIndex = i;
    });
  }

  Future<void> _handleCallTap() async {
    final hasCircle = AppStorage.getCircle().isNotEmpty;
    if (!hasCircle) {
      await _showFinishSetupSheet();
      return;
    }

    if (!mounted) return;
    Navigator.pushNamed(context, AppRouter.call);
  }

  Future<void> _showFinishSetupSheet() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.90),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Finish setup",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "To start today’s mystery call, you need a circle first.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          await Navigator.pushNamed(context, AppRouter.circle);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "CREATE CIRCLE",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          await Navigator.pushNamed(context, AppRouter.contacts);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB75AFE),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "SYNC CONTACTS",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "You can sync later — but you need a circle to call.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.52),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bodyForIndex(int i) {
    if (i == 2) return _bodyForIndex(_lastNonCallIndex);

    switch (i) {
      case 0:
        return TodayScreen(
          currentTabIndex: _index,
          onTabChange: _setIndex,
          onCallTap: _handleCallTap,
        );
      case 1:
        return CircleScreen();
      case 3:
        return const PlusPaywallScreen();
      case 4:
        return const ProfileHubScreen();
      default:
        return TodayScreen(
          currentTabIndex: _index,
          onTabChange: _setIndex,
          onCallTap: _handleCallTap,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: _bodyForIndex(_index),
    );
  }
}