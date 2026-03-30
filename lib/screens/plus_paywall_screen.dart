// lib/screens/plus_paywall_screen.dart
import 'package:flutter/material.dart';

import '../theme/know_no_know_theme.dart';
import 'app_shell.dart';

class PlusPaywallScreen extends StatelessWidget {
  const PlusPaywallScreen({super.key});

  void _showNotWiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Not wired yet",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "Purchases aren’t connected yet.\n\n"
          "When you're ready, I’ll wire RevenueCat / StoreKit / Play Billing and this button will unlock Plus.",
          style: TextStyle(fontWeight: FontWeight.w700, height: 1.25),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  void _goToToday(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AppShell(initialIndex: 0),
      ),
      (route) => false,
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String priceLine,
    required String tag,
    required bool featured,
    required List<String> bullets,
  }) {
    final bg = featured ? const Color(0xFF0E0E12) : const Color(0xFF0B0B0C);
    final border = featured
        ? KnowNoKnowTheme.primary.withOpacity(0.55)
        : Colors.white.withOpacity(0.10);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: featured ? 1.6 : 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(featured ? 0.35 : 0.25),
            blurRadius: featured ? 34 : 26,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag.toUpperCase(),
            style: TextStyle(
              color: featured
                  ? KnowNoKnowTheme.primary.withOpacity(0.95)
                  : Colors.white.withOpacity(0.60),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            priceLine,
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...bullets.map(_bullet),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const plusPrice = "\$6.99 / month";

    final freeBullets = <String>[
      "One Mystery Call per Day",
      "Each call is 6:30 by default.",
      "A +5 minute extension may appear occasionally (not guaranteed).",
      "The +5 extension is shared — ONE button for both people.",
      "3 total extensions per rolling 7-day window.",
      "Sometimes the extension shows up with a special look.",
    ];

    final plusBullets = <String>[
      "Up to 3 mystery calls per day.",
      "Each call comes from a different circle.",
      "Name + define your circles (Family / Close Friends / Work).",
      "Every call is 6:30.",
      "Guaranteed one-time +5 extension on every Plus call.",
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/logo_black.png',
          height: 65,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            onPressed: () => _goToToday(context),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
            tooltip: "Close",
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const Text(
                "More Calls.\nMore Control.\nStill Mystery.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Plus gives you more daily momentum — without interrupting the call with hard upsells.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _planCard(
                      title: "Free",
                      priceLine: "Default experience",
                      tag: "Free",
                      featured: false,
                      bullets: freeBullets,
                    ),
                    const SizedBox(height: 12),
                    _planCard(
                      title: "Plus",
                      priceLine: "$plusPrice • Cancel anytime",
                      tag: "PLUS — UNLOCKED",
                      featured: true,
                      bullets: plusBullets,
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 62,
                child: ElevatedButton(
                  onPressed: () => _showNotWiredDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KnowNoKnowTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "GET PLUS — \$6.99/mo",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Purchases not wired yet. Cancel anytime after you subscribe.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}