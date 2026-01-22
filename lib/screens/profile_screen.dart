// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../app_router.dart';
import '../storage.dart';
import '../theme/know_no_know_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: AppStorage.getProfileName());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _error = 'Enter your name');
      return;
    }

    await AppStorage.setProfile(name: n);
    if (!mounted) return;

    final hasCircle = AppStorage.getCircle().isNotEmpty;
    Navigator.pushReplacementNamed(
      context,
      hasCircle ? AppRouter.today : AppRouter.circle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "YOUR PROFILE",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  "Let’s set your name.",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: KnowNoKnowTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  "This is what your Mysto will see after the reveal.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KnowNoKnowTheme.mutedInk,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 14),

                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "DISPLAY NAME",
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: KnowNoKnowTheme.mutedInk,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _name,
                        onChanged: (_) => setState(() => _error = null),
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          color: KnowNoKnowTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: InputDecoration(
                          hintText: "Zion",
                          errorText: _error,
                          prefixIcon: const Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 18,
                            color: KnowNoKnowTheme.mutedInk,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Your daily match stays secret until you JOIN.",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: KnowNoKnowTheme.mutedInk,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KnowNoKnowTheme.ink,
                      foregroundColor: KnowNoKnowTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "CONTINUE",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: KnowNoKnowTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}
