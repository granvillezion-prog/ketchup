import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme/know_no_know_theme.dart';
import 'storage.dart';
import 'subscription.dart';
import 'app_router.dart';

Future<void> main() async {
  // ✅ Bindings init in the SAME zone as runApp
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Catch framework errors (widgets/layout/build/etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FLUTTER_ERROR] ${details.exceptionAsString()}');
    if (details.stack != null) debugPrint('${details.stack}');
  };

  // ✅ Catch async/platform errors that can crash silently in release
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[PLATFORM_ERROR] $error');
    debugPrint('$stack');

    // In debug/profile: DO NOT hide it. Crash so you see it.
    assert(() {
      return false;
    }());

    // In release: handled (later: send to Crashlytics and return true)
    return true;
  };

  // ✅ Boot before UI (stable + predictable)
  try {
    debugPrint('[BOOT] Firebase.initializeApp()...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[BOOT] Firebase.initializeApp() OK');

    debugPrint('[BOOT] storage/subscription init...');
    await AppStorage.init();
    await Subscription.init();
    await Subscription.load();
    debugPrint('[BOOT] storage/subscription init OK');
  } catch (e, st) {
    debugPrint('[BOOT] FAILED: $e');
    debugPrint('$st');
    // We still run the app so you can surface a UI/state fallback if needed.
  }

  runApp(const KnowNoKnowApp());
}

class KnowNoKnowApp extends StatelessWidget {
  const KnowNoKnowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Know No Know',
      debugShowCheckedModeBanner: false,
      theme: KnowNoKnowTheme.theme(),

      // ✅ Router is the single source of truth (no competing `home:` root)
      onGenerateRoute: AppRouter.onGenerateRoute,

      // ✅ Make the router own startup
      initialRoute: AppRouter.splash,
    );
  }
}
