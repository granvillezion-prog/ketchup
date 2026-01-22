// lib/contacts_screen.dart
import 'package:flutter/material.dart';
import 'theme/know_no_know_theme.dart';

class ContactsScreen extends StatefulWidget {
  final List<String> existingNames;
  final Future<void> Function(String name) onAdd;

  const ContactsScreen({
    super.key,
    required this.existingNames,
    required this.onAdd,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _c.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Enter a name.");
      return;
    }
    if (widget.existingNames.contains(name)) {
      setState(() => _error = "Already in your circle.");
      return;
    }

    setState(() => _error = null);
    await widget.onAdd(name);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KnowNoKnowTheme.subwayBlack,
      appBar: AppBar(
        title: const Text(
          "ADD TO CIRCLE",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: KnowNoKnowTheme.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: KnowNoKnowTheme.stroke),
          ),
          child: Column(
            children: [
              TextField(
                controller: _c,
                style: const TextStyle(
                  color: KnowNoKnowTheme.subwayWhite,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: "Type a friend's name…",
                  hintStyle: const TextStyle(color: KnowNoKnowTheme.muted),
                  filled: true,
                  fillColor: KnowNoKnowTheme.subwayBlack,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: KnowNoKnowTheme.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: KnowNoKnowTheme.stroke),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _add,
                  child: const Text("ADD"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
