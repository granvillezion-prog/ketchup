// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'auth/auth_service.dart';
import 'services/user_service.dart';
import 'app_router.dart';
import 'theme/know_no_know_theme.dart';
import 'storage.dart';
import 'subscription.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppStorage.init(); 
  await Subscription.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AuthService.ensureSignedIn();
  await UserService.ensureUserDoc();
  await Subscription.load();

  runApp(const KnowNoKnowApp());
}

class KnowNoKnowApp extends StatelessWidget {
  const KnowNoKnowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Know No Know",
      debugShowCheckedModeBanner: false,
      theme: KnowNoKnowTheme.theme(),
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
