// lib/app_router.dart
import 'package:flutter/material.dart';

import 'storage.dart';
import 'app_state.dart';
import 'models.dart';
import 'theme/know_no_know_theme.dart';

import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/circle_screen.dart';
import 'screens/today_screen.dart';
import 'screens/call_screen.dart';
import 'screens/reveal_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/plus_paywall_screen.dart';

class AppRouter {
  static const splash = '/';
  static const auth = '/auth';
  static const profile = '/profile';
  static const circle = '/circle';
  static const today = '/today';
  static const call = '/call';
  static const reveal = '/reveal';
  static const settings = '/settings';
  static const plus = '/plus';

  /// ✅ Convenience: open the Plus paywall from anywhere
  static Future<void> openPlus(BuildContext context) async {
    await Navigator.pushNamed(context, plus);
  }

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return _fade(const _SplashGate());
      case auth:
        return _slide(const AuthScreen());
      case profile:
        return _slide(const ProfileScreen());
      case circle:
        return _slide(const CircleScreen());
      case today:
        return _slide(const TodayScreen());
      case call:
        return _slide(const _CallGate());
      case reveal:
        return _popFade(const _RevealGate());
      case settings:
        return _slide(const SettingsScreen());
      case plus:
        return _popFade(const PlusPaywallScreen());
      default:
        return _fade(const _UnknownRoute());
    }
  }

  static PageRouteBuilder _fade(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  static PageRouteBuilder _popFade(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  static PageRouteBuilder _slide(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        final offset = Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curved);
        return SlideTransition(
          position: offset,
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// CALL route gate
/// ---------------------------------------------------------------------------
class _CallGate extends StatefulWidget {
  const _CallGate();

  @override
  State<_CallGate> createState() => _CallGateState();
}

class _CallGateState extends State<_CallGate> {
  bool _loading = true;
  MockPair? _pair;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // If no circle, send to Circle first
    if (AppStorage.getCircle().isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.circle);
      return;
    }

    // Ensure today's pair is created/hydrated
    final p = await AppState.ensureTodayPair();
    if (!mounted) return;

    if (p == null) {
      Navigator.pushReplacementNamed(context, AppRouter.today);
      return;
    }

    setState(() {
      _pair = p;
      _loading = false;
    });

    // If timer was started and already at 0, finish immediately.
    final remaining = AppState.getRemainingCallSeconds();
    if (remaining != null && remaining <= 0) {
      await AppState.markCallComplete();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.reveal);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingShell();

    final pair = _pair;
    if (pair == null) return const _LoadingShell();

    return CallScreen(
      hiddenName: pair.hiddenName,
      phone: pair.phone, // ✅ keep your existing signature
      onConnect: () {},
      onComplete: () async {
        await AppState.markCallComplete();
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, AppRouter.reveal);
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// REVEAL route gate
/// ---------------------------------------------------------------------------
class _RevealGate extends StatefulWidget {
  const _RevealGate();

  @override
  State<_RevealGate> createState() => _RevealGateState();
}

class _RevealGateState extends State<_RevealGate> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // If no circle, can't reveal anything.
    if (AppStorage.getCircle().isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.circle);
      return;
    }

    // Ensure pair exists/hydrated
    await AppState.ensureTodayPair();
    if (!mounted) return;

    final pair = AppStorage.getTodayPair();
    if (pair == null) {
      Navigator.pushReplacementNamed(context, AppRouter.today);
      return;
    }

    // Hard gate: only allow reveal if completed
    if (!pair.callCompleted) {
      final remaining = AppState.getRemainingCallSeconds();
      final hasActive = remaining != null && remaining > 0;

      if (hasActive) {
        Navigator.pushReplacementNamed(context, AppRouter.call);
      } else {
        Navigator.pushReplacementNamed(context, AppRouter.today);
      }
      return;
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingShell();
    return const RevealScreen();
  }
}

/// Simple consistent loading shell
class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: _GradientLoading(),
    );
  }
}

class _GradientLoading extends StatelessWidget {
  const _GradientLoading();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));

    final authed = AppStorage.isAuthed();
    if (!authed) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.auth);
      return;
    }

    final profileDone = AppStorage.isProfileComplete();
    if (!profileDone) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.profile);
      return;
    }

    final hasCircle = AppStorage.getCircle().isNotEmpty;
    if (!hasCircle) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.circle);
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.today);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              gradient: KnowNoKnowTheme.cardGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: KnowNoKnowTheme.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/app_icon_work.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.chat_bubble_rounded,
                          color: KnowNoKnowTheme.white,
                          size: 34,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Know No Know',
                  style: TextStyle(
                    color: KnowNoKnowTheme.ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Daily mystery catch-ups',
                  style: TextStyle(
                    color: KnowNoKnowTheme.mutedInk,
                    fontWeight: FontWeight.w800,
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

class _UnknownRoute extends StatelessWidget {
  const _UnknownRoute();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
        child: Center(
          child: Text(
            'Unknown route',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}
