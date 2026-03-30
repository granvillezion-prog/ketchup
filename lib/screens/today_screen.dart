import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_router.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/friends_graph_service.dart';
import '../services/progress_service.dart';
import '../storage.dart';
import 'profile_hub_screen.dart';
import 'circle_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    this.currentTabIndex = 0,
    this.onTabChange,
    this.onCallTap,
  });

  final int currentTabIndex;
  final void Function(int)? onTabChange;
  final Future<void> Function()? onCallTap;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

String _getMatchState(MockPair pair) {
  final type = pair.circleName.toLowerCase();

  if (pair.hiddenName == 'Add more friends') {
    return 'unmatched';
  }

  if (type == 'direct_on_app') return 'primary';
  if (type == 'friend_of_friend') return 'secondary';
  if (type == 'circle_fallback') return 'fallback';
  if (type == 'late_join_reserve') return 'reserve';
  if (type == 'unmatched_priority_tomorrow') return 'unmatched';

  return 'unknown';
}

class _TodayScreenState extends State<TodayScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MockPair? _pair;

  Timer? _ticker;
  int? _remainingCallSeconds;
  String _nextDropText = '';

  late final AnimationController _mysteryCtrl;

  List<String> _myFriends = const [];
  bool _popupScheduledThisSession = false;
  bool _missedYesterday = false;

  final ScrollController _myFriendsCtrl = ScrollController();

  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraInitializing = false;

  bool _showEditMenu = false;
  bool _startingCall = false;
  String _callLaunchText = '';

  static const int _friendsVisibleCount = 7;
  static const double _friendRowHeight = 76.0;

  static const Color _neonReady = Color(0xFF4cfd02);
  static const Color _iosGlassDark = Color(0x55343438);
  static const Color _iosPurple = Color(0xFFB75AFF);
  static const Color _warnAmber = Color(0xFFFFB347);

  static const Color _answerCardBg = Color(0xE6000000);
  static const Color _hintNeon = Color(0xFF4cfd02);

  static const double _flipCardHeight = 152.0;
  static const EdgeInsets _compactCardPadding =
      EdgeInsets.fromLTRB(14, 12, 14, 10);
  static const double _compactEyebrowGap = 4.0;

  static const String _answerFontFamily = 'Jersey25';
  static const String _clueFontFamily = 'PermanentMarker';

  final TextEditingController _answerCtrl = TextEditingController();
  bool _sendingAnswer = false;

  int _pollTick = 0;
  bool _showAnswerSide = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _mysteryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _startTicker();
    _loadFriends();
    _load();
    _initFrontCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _mysteryCtrl.dispose();
    _myFriendsCtrl.dispose();
    _answerCtrl.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      cam.dispose();
      _cameraController = null;
      if (mounted) {
        setState(() => _cameraReady = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      _initFrontCamera();
      ProgressService.touchActiveNow();
      _load();
    }
  }

  Future<void> _initFrontCamera() async {
    if (_cameraInitializing) return;
    _cameraInitializing = true;

    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      CameraDescription? front;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          front = cam;
          break;
        }
      }

      front ??= cameras.isNotEmpty ? cameras.first : null;
      if (front == null) return;

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _cameraController?.dispose();

      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cameraReady = false);
    } finally {
      _cameraInitializing = false;
    }
  }

  void _startTicker() {
    _ticker?.cancel();

    _remainingCallSeconds = AppState.getRemainingCallSeconds();
    _nextDropText = _computeNextDropText();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      final nextRem = AppState.getRemainingCallSeconds();
      final nextDrop = _computeNextDropText();

      _pollTick = (_pollTick + 1) % 5;
      if (_pollTick == 0) {
        final updated = await AppState.pollIncomingAnonymousAnswer();
        if (!mounted) return;
        if (updated != null) {
          setState(() => _pair = updated);
        }
      }

      if (nextRem != _remainingCallSeconds || nextDrop != _nextDropText) {
        setState(() {
          _remainingCallSeconds = nextRem;
          _nextDropText = nextDrop;
        });
      }
    });
  }

  void _flipToAnswer() {
    if (_showAnswerSide) return;
    setState(() => _showAnswerSide = true);
  }

  void _flipToClue() {
    if (!_showAnswerSide) return;
    FocusScope.of(context).unfocus();
    setState(() => _showAnswerSide = false);
  }

  void _toggleEditMenu() {
    setState(() => _showEditMenu = !_showEditMenu);
  }

  void _closeEditMenu() {
    if (!_showEditMenu) return;
    setState(() => _showEditMenu = false);
  }

  Future<void> _openProfileFromMenu() async {
    _closeEditMenu();
    await Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => const ProfileHubScreen(),
      ),
    );
  }

  Future<void> _openFriendsFromMenu() async {
    _closeEditMenu();
    await Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => const CircleScreen(),
      ),
    );
    if (!mounted) return;
    await _loadFriends();
    await _load();
  }

  String _formatClock(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  String _computeNextDropText() {
    final now = DateTime.now();
    final nextMidnight =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final diff = nextMidnight.difference(now);

    final h = diff.inHours;
    final m = diff.inMinutes % 60;

    if (h <= 0 && m <= 0) return 'soon';
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  Future<void> _load() async {
    await ProgressService.ensureUserDoc();
    await ProgressService.touchActiveNow();

    final hasCircle = AppStorage.getCircle().isNotEmpty;

    if (!hasCircle) {
      final missedYesterday = await ProgressService.wasYesterdayMissed();
      if (!mounted) return;
      setState(() {
        _pair = null;
        _missedYesterday = missedYesterday;
        _remainingCallSeconds = AppState.getRemainingCallSeconds();
        _nextDropText = _computeNextDropText();
      });
      return;
    }

    final p = await AppState.ensureTodayPair();
    final p2 = await AppState.pollIncomingAnonymousAnswer();
    final missedYesterday = await ProgressService.wasYesterdayMissed();

    if (!mounted) return;

    final finalPair = p2 ?? p;

    setState(() {
      _pair = finalPair;
      _missedYesterday = missedYesterday;
      _remainingCallSeconds = AppState.getRemainingCallSeconds();
      _nextDropText = _computeNextDropText();

      final mine = (finalPair?.myAnswerText ?? '').trim();
      if (mine.isNotEmpty) _answerCtrl.text = mine;
    });
  }

  Future<void> _loadFriends() async {
    try {
      final realFriends = await FriendsGraphService.getMyOnAppFriendNames();
      if (!mounted) return;

      if (realFriends.isNotEmpty) {
        setState(() => _myFriends = realFriends);
        return;
      }
    } catch (_) {}

    final fallback = FriendsGraphService.getMyFriendsLocal();
    if (!mounted) return;
    setState(() => _myFriends = fallback);
  }

  Future<void> _goContacts() async {
    await Navigator.pushNamed(context, AppRouter.contacts);
    if (!mounted) return;
    await _loadFriends();
    await _load();
    setState(() {});
  }

  Future<void> _goCircle() async {
    await Navigator.pushNamed(context, AppRouter.circle);
    if (!mounted) return;
    await _load();
    await _loadFriends();
    setState(() {});
  }

  Future<void> _goPlusTab() async {
    widget.onTabChange?.call(3);
  }

  void _maybeShowContactsSyncPopup() {
    if (_popupScheduledThisSession) return;

    final hasCircle = AppStorage.getCircle().isNotEmpty;
    final contactsSynced = AppStorage.areContactsSynced();
    final dismissedForever = AppStorage.isContactsSyncPopupDismissed();

    if (!hasCircle) return;
    if (contactsSynced) return;
    if (dismissedForever) return;

    _popupScheduledThisSession = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showGeneralDialog(
        context: context,
        barrierLabel: 'contacts_sync_popup',
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (ctx, anim1, anim2) {
          final t = Curves.easeOut.transform(anim1.value);

          Future<void> closeOnly() async {
            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
          }

          Future<void> dismissForeverAndClose() async {
            await AppStorage.setContactsSyncPopupDismissed(true);
            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
          }

          return GestureDetector(
            onTap: closeOnly,
            child: Center(
              child: Transform.scale(
                scale: 0.96 + (0.04 * t),
                child: Opacity(
                  opacity: t,
                  child: GestureDetector(
                    onTap: () {},
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 18),
                        child: _GlassPanel(
                          borderRadius: 22,
                          color: Colors.black.withOpacity(0.55),
                          child: Stack(
                            children: [
                              Positioned(
                                right: 0,
                                top: 0,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: dismissForeverAndClose,
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 44, 14),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'OPTIONAL',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.75),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Sync contacts to see who’s already on the app.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.92),
                                        fontWeight: FontWeight.w900,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      height: 44,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (Navigator.canPop(ctx)) {
                                            Navigator.pop(ctx);
                                          }
                                          await _goContacts();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _iosPurple,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Text(
                                          'SYNC',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, a1, a2, child) => child,
      );
    });
  }

  double _friendsBoxHeight(int total) {
    final visible = math.min(total, _friendsVisibleCount);
    return visible * _friendRowHeight;
  }

  Widget _invisibleScrollableList({
    required ScrollController controller,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: ScrollConfiguration(
        behavior: const _NoScrollGlow(),
        child: Scrollbar(
          controller: controller,
          thumbVisibility: false,
          trackVisibility: false,
          interactive: false,
          thickness: 0.0,
          child: ListView.builder(
            controller: controller,
            padding: EdgeInsets.zero,
            itemCount: itemCount,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            itemBuilder: itemBuilder,
          ),
        ),
      ),
    );
  }

  Future<void> _sendAnswer() async {
    final pair = _pair;
    if (pair == null) return;
    if (_sendingAnswer) return;

    final trimmed = _answerCtrl.text.trim();
    if (trimmed.isEmpty) return;

    setState(() => _sendingAnswer = true);

    try {
      final updated = await AppState.sendMyAnswerAnonymous(trimmed);
      if (!mounted) return;
      setState(() => _pair = updated ?? _pair);
      FocusScope.of(context).unfocus();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send yet. Try again.'),
          duration: Duration(milliseconds: 1100),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _sendingAnswer = false);
    }
  }

  Future<void> _handleCallTap() async {
    final pair = _pair;

    if (_startingCall) return;

    if (pair == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Today’s call is not ready yet.'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }

    if (pair.hiddenName == 'Add more friends') {
      await _goCircle();
      return;
    }

    if (widget.onCallTap != null) {
      await widget.onCallTap!.call();
      return;
    }

    setState(() {
      _startingCall = true;
      _callLaunchText = 'Connecting...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    setState(() {
      _callLaunchText = 'Opening call...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    await Navigator.pushNamed(context, AppRouter.call);
    if (!mounted) return;

    setState(() {
      _startingCall = false;
      _callLaunchText = '';
    });

    await _load();
  }

  String _statusDetailText(MockPair pair) {
    final state = _getMatchState(pair);

    switch (state) {
      case 'primary':
        return 'Someone in your circle';
      case 'secondary':
        return 'Friend of a friend';
      case 'fallback':
        return 'From your contacts';
      case 'reserve':
        return 'Late-join reserve match';
      case 'unmatched':
        return 'Add more active friends to improve your daily pool';
      default:
        return '';
    }
  }

  Widget _flipCard({required MockPair pair}) {
    final myAnswerSent = pair.myAnswerText.trim().isNotEmpty;

    final front = _MysterySweepCard(
      controller: _mysteryCtrl,
      child: _GlassHeroCard(
        eyebrow: "Today's Question",
        eyebrowFontFamily: _clueFontFamily,
        backgroundColor: Colors.white.withOpacity(0.16),
        eyebrowColor: Colors.white.withOpacity(0.92),
        padding: _compactCardPadding,
        eyebrowGap: _compactEyebrowGap,
        onTap: _flipToAnswer,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 34),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“${pair.answerText.isNotEmpty ? pair.answerText : "…"}”',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _answerFontFamily,
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w400,
                      height: 1.06,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pair.questionText.isNotEmpty
                        ? pair.questionText
                        : AppState.getQuestionById(pair.questionId).text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _clueFontFamily,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      height: 1.2,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              right: 0,
              top: -6,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.swap_vert_rounded,
                  color: _iosPurple,
                  size: 26,
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: _flipToAnswer,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(width: 34, height: 34),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final back = _GlassHeroCard(
      eyebrow: 'Your Answer',
      eyebrowFontFamily: _clueFontFamily,
      backgroundColor: _answerCardBg,
      eyebrowColor: _iosPurple,
      padding: _compactCardPadding,
      eyebrowGap: _compactEyebrowGap,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextSelectionTheme(
                data: TextSelectionThemeData(
                  cursorColor: _hintNeon,
                  selectionColor: _hintNeon.withOpacity(0.25),
                  selectionHandleColor: _hintNeon,
                ),
                child: SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _answerCtrl,
                    enabled: !myAnswerSent && !_sendingAnswer,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: myAnswerSent ? 'Sent.' : 'Your answer...',
                      hintStyle: const TextStyle(
                        fontFamily: _clueFontFamily,
                        color: _hintNeon,
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.fromLTRB(10, 2, 44, 2),
                    ),
                    style: const TextStyle(
                      fontFamily: _answerFontFamily,
                      color: _hintNeon,
                      fontWeight: FontWeight.w400,
                      fontSize: 20,
                      height: 1.05,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 28,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: (myAnswerSent || _sendingAnswer) ? null : _sendAnswer,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: (myAnswerSent || _sendingAnswer) ? 0.35 : 1,
                      child: const Icon(
                        Icons.send_rounded,
                        color: _iosPurple,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: _flipToClue,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(width: 34, height: 34),
              ),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: _flipCardHeight,
      width: double.infinity,
      child: _FlipCard(
        showBack: _showAnswerSide,
        front: front,
        back: back,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCircle = AppStorage.getCircle().isNotEmpty;

    _maybeShowContactsSyncPopup();

    final pair = _pair;
    final rem = _remainingCallSeconds;
    final hasActiveCall = rem != null && rem > 0;

    String statusText = '';
    Color statusColor = Colors.white.withOpacity(0.9);

    if (pair != null) {
      final state = _getMatchState(pair);

      if (pair.callCompleted) {
        statusText = 'Call done';
        statusColor = Colors.white.withOpacity(0.7);
      } else if (hasActiveCall) {
        statusText = 'On call now';
        statusColor = Colors.white;
      } else {
        switch (state) {
          case 'primary':
            statusText = 'Ready to connect';
            statusColor = _neonReady;
            break;
          case 'secondary':
            statusText = 'New connection';
            statusColor = _iosPurple;
            break;
          case 'fallback':
            statusText = 'From your circle';
            statusColor = Colors.white.withOpacity(0.85);
            break;
          case 'reserve':
            statusText = 'Reserve match';
            statusColor = _iosPurple;
            break;
          case 'unmatched':
            statusText = 'Add more friends';
            statusColor = Colors.redAccent;
            break;
          default:
            statusText = 'Ready';
        }
      }
    }

    final statusDetail =
        pair == null || pair.callCompleted ? '' : _statusDetailText(pair);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeEditMenu,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: _cameraReady && _cameraController != null
                  ? _FrontCameraBackground(controller: _cameraController!)
                  : Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/today_screen4.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.50),
              ),
            ),
            SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TopUtilityRow(onEditTap: _toggleEditMenu),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 90,
                              child: Image.asset(
                                'assets/logo3.png',
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                errorBuilder: (_, __, ___) {
                                  return const Text(
                                    'logo3.png missing',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _TopActionRow(
                            onPlusTap: _goPlusTab,
                            onCallTap: _handleCallTap,
                          ),
                          const SizedBox(height: 18),
                          if (!hasCircle) ...[
                            _GlassHeroCard(
                              eyebrow: 'Finish Setup',
                              eyebrowColor: Colors.white.withOpacity(0.75),
                              backgroundColor: _iosGlassDark,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You need at least 5 people in your circle before your daily call unlocks.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.86),
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ActionButton(
                                          text: 'CREATE CIRCLE',
                                          filled: true,
                                          onTap: _goCircle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _ActionButton(
                                          text: 'SYNC CONTACTS',
                                          filled: false,
                                          onTap: _goContacts,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Your app is not ready until your circle is real.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.58),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            if (pair == null) ...[
                              const SizedBox(height: 14),
                              const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ] else ...[
                              _GlassStatusRow(
                                left: statusText,
                                right: pair.callCompleted
                                    ? 'NEXT • $_nextDropText'
                                    : '',
                                leftColor: statusColor,
                              ),
                              if (_missedYesterday &&
                                  !pair.callCompleted &&
                                  !hasActiveCall) ...[
                                const SizedBox(height: 6),
                                Text(
                                  "You missed yesterday's call.",
                                  style: TextStyle(
                                    color: _warnAmber,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (statusDetail.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  statusDetail,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.68),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _GlassPill(
                                    text: '⭐ ${pair.points}',
                                    filled: true,
                                  ),
                                  const SizedBox(width: 10),
                                  _GlassPill(
                                    text: '🔥 ${pair.currentStreak}',
                                    filled: true,
                                  ),
                                  const Spacer(),
                                  _GlassPill(
                                    text:
                                        'CALLS ${pair.callIndex}/${pair.totalCalls}',
                                    filled: false,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _flipCard(pair: pair),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.zero,
                                color: Colors.transparent,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'YOUR PEOPLE',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.72),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      height: 1,
                                      color: Colors.white.withOpacity(0.16),
                                    ),
                                    const SizedBox(height: 12),
                                    if (_myFriends.isEmpty)
                                      Text(
                                        'No friends yet.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    else
                                      _invisibleScrollableList(
                                        controller: _myFriendsCtrl,
                                        itemCount: _myFriends.length,
                                        height:
                                            _friendsBoxHeight(_myFriends.length),
                                        itemBuilder: (context, i) {
                                          final n = _myFriends[i];
                                          final isLast =
                                              i == _myFriends.length - 1;

                                          return SizedBox(
                                            height: _friendRowHeight,
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: _CallListRow(
                                                      name: n,
                                                      iconId: AppStorage
                                                          .getFriendIconId(n),
                                                      dateText: '',
                                                      accentColor: _iosPurple,
                                                    ),
                                                  ),
                                                ),
                                                if (!isLast)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                      left: 62,
                                                    ),
                                                    height: 1,
                                                    color: Colors.white
                                                        .withOpacity(0.16),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (hasActiveCall && rem != null)
                                Text(
                                  'Call in progress • ${_formatClock(rem)} remaining',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.74),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_startingCall)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.22),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: _iosPurple,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _callLaunchText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_showEditMenu)
              Positioned(
                left: 18,
                top: 46,
                child: _EditDropdownMenu(
                  onProfileTap: _openProfileFromMenu,
                  onFriendsTap: _openFriendsFromMenu,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.showBack,
    required this.front,
    required this.back,
  });

  final bool showBack;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: showBack ? 1 : 0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOut,
      builder: (context, t, _) {
        final angle = t * math.pi;
        final showingBack = angle > (math.pi / 2);

        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(angle);

        return Transform(
          alignment: Alignment.center,
          transform: m,
          child: showingBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateX(math.pi),
                  child: back,
                )
              : front,
        );
      },
    );
  }
}

class _NoScrollGlow extends ScrollBehavior {
  const _NoScrollGlow();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _TopUtilityRow extends StatelessWidget {
  const _TopUtilityRow({
    required this.onEditTap,
  });

  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEditTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Edit',
              style: TextStyle(
                color: Color(0xFFB75AFF),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopActionRow extends StatelessWidget {
  const _TopActionRow({
    required this.onPlusTap,
    required this.onCallTap,
  });

  final VoidCallback onPlusTap;
  final VoidCallback onCallTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WideTopActionTile(
            height: 78,
            icon: Icons.star_rounded,
            label: 'Plus',
            background: const Color(0x665B5B5F),
            onTap: onPlusTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _WideTopActionTile(
            height: 78,
            label: 'Got KnowTime',
            background: const Color(0xFFB75AFF),
            onTap: onCallTap,
            useKnowTimeIcon: true,
          ),
        ),
      ],
    );
  }
}

class _WideTopActionTile extends StatefulWidget {
  const _WideTopActionTile({
    required this.height,
    this.icon,
    required this.label,
    required this.background,
    required this.onTap,
    this.useKnowTimeIcon = false,
  });

  final double height;
  final IconData? icon;
  final String label;
  final Color background;
  final VoidCallback onTap;
  final bool useKnowTimeIcon;

  @override
  State<_WideTopActionTile> createState() => _WideTopActionTileState();
}

class _WideTopActionTileState extends State<_WideTopActionTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.965 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: _GlassPanel(
          borderRadius: 18,
          color: widget.background,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            onTap: widget.onTap,
            child: SizedBox(
              width: double.infinity,
              height: widget.height,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.useKnowTimeIcon)
                      Transform.translate(
                        offset: const Offset(0, -2),
                        child: const _KnowTimeIcon(),
                      )
                    else
                      Icon(widget.icon, color: Colors.white, size: 34),
                    const SizedBox(height: 8),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KnowTimeIcon extends StatelessWidget {
  const _KnowTimeIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      CupertinoIcons.video_camera_solid,
      color: Colors.white,
      size: 36,
    );
  }
}

class _EditDropdownMenu extends StatelessWidget {
  const _EditDropdownMenu({
    required this.onProfileTap,
    required this.onFriendsTap,
  });

  final VoidCallback onProfileTap;
  final VoidCallback onFriendsTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 168,
          decoration: BoxDecoration(
            color: const Color(0xCC303033),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EditMenuRow(
                text: 'Profile',
                icon: CupertinoIcons.person_crop_circle,
                onTap: onProfileTap,
                showBottomBorder: true,
              ),
              _EditMenuRow(
                text: 'Friends',
                icon: CupertinoIcons.check_mark_circled,
                onTap: onFriendsTap,
                showBottomBorder: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditMenuRow extends StatelessWidget {
  const _EditMenuRow({
    required this.text,
    required this.icon,
    required this.onTap,
    required this.showBottomBorder,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: showBottomBorder
              ? Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
            Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.borderRadius = 26,
    this.color = const Color(0x663A3A3F),
  });

  final Widget child;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassHeroCard extends StatelessWidget {
  const _GlassHeroCard({
    required this.eyebrow,
    required this.child,
    this.backgroundColor,
    this.eyebrowColor,
    this.eyebrowFontFamily,
    this.padding,
    this.eyebrowGap,
    this.onTap,
  });

  final String eyebrow;
  final Widget child;
  final Color? backgroundColor;
  final Color? eyebrowColor;
  final String? eyebrowFontFamily;
  final EdgeInsets? padding;
  final double? eyebrowGap;
  final VoidCallback? onTap;

  final String? _unused = null;

  @override
  Widget build(BuildContext context) {
    final showEyebrow = eyebrow.trim().isNotEmpty;

    final content = _GlassPanel(
      borderRadius: 26,
      color: backgroundColor ?? const Color(0x663A3A3F),
      child: Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showEyebrow) ...[
              Text(
                eyebrow,
                style: TextStyle(
                  fontFamily: eyebrowFontFamily,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: eyebrowColor ?? Colors.white.withOpacity(0.7),
                  letterSpacing: 0.9,
                ),
              ),
              SizedBox(height: eyebrowGap ?? 10),
            ],
            child,
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class _GlassStatusRow extends StatelessWidget {
  const _GlassStatusRow({
    super.key,
    required this.left,
    required this.right,
    this.leftColor,
  });

  final String left;
  final String right;
  final Color? leftColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: TextStyle(
              color: leftColor ?? Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        if (right.trim().isNotEmpty)
          Text(
            right,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
      ],
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.text,
    required this.filled,
  });

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: filled
            ? Colors.white.withOpacity(0.14)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(filled ? 0.14 : 0.10),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.94),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.text,
    required this.filled,
    required this.onTap,
  });

  final String text;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              filled ? const Color(0xFFB75AFF) : Colors.white.withOpacity(0.10),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.white.withOpacity(filled ? 0.0 : 0.10),
            ),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _MysterySweepCard extends StatelessWidget {
  const _MysterySweepCard({
    required this.controller,
    required this.child,
  });

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        return CustomPaint(
          painter: _MysterySweepPainter(t: controller.value),
          child: child,
        );
      },
    );
  }
}

class _MysterySweepPainter extends CustomPainter {
  _MysterySweepPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(26));

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.06);

    canvas.drawRRect(rr, base);

    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        Colors.transparent,
        const Color(0xFFB75AFF).withOpacity(0.0),
        const Color(0xFFB75AFF).withOpacity(0.55),
        const Color(0xFFB75AFF).withOpacity(0.0),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.50, 0.75, 1.0],
      transform: GradientRotation(t * math.pi * 2),
    );

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = sweep.createShader(rect);

    canvas.drawRRect(rr.deflate(1), glow);
  }

  @override
  bool shouldRepaint(covariant _MysterySweepPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class _FrontCameraBackground extends StatelessWidget {
  const _FrontCameraBackground({
    required this.controller,
  });

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.expand();
    }

    final preview = CameraPreview(controller);

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.previewSize?.height ??
              MediaQuery.of(context).size.width,
          height: controller.value.previewSize?.width ??
              MediaQuery.of(context).size.height,
          child: preview,
        ),
      ),
    );
  }
}

class _CallListRow extends StatelessWidget {
  const _CallListRow({
    required this.name,
    required this.iconId,
    required this.dateText,
    required this.accentColor,
  });

  final String name;
  final String? iconId;
  final String dateText;
  final Color accentColor;

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    return (parts[0].characters.take(1).toString() +
            parts[1].characters.take(1).toString())
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final label = (iconId != null && iconId!.trim().isNotEmpty)
        ? iconId!.trim().toUpperCase()
        : _initials(name);

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withOpacity(0.18),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
        if (dateText.trim().isNotEmpty)
          Text(
            dateText,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}