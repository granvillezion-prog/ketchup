import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../storage.dart';
import '../theme/know_no_know_theme.dart';

class IconPickerScreen extends StatefulWidget {
  const IconPickerScreen({super.key});

  @override
  State<IconPickerScreen> createState() => _IconPickerScreenState();
}

class _IconPickerScreenState extends State<IconPickerScreen> {
  List<String> _iconIds = const [];
  bool _loading = true;

  // mode
  bool _forFriend = false;
  String _friendName = '';

  String _selectedId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Read args once when widget is first built
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final mode = (args['mode'] ?? '').toString().trim(); // 'self' | 'friend'
      final friendName = (args['friendName'] ?? '').toString().trim();

      _forFriend = mode == 'friend' && friendName.isNotEmpty;
      _friendName = friendName;
    }

    _selectedId = _forFriend
        ? AppStorage.getFriendIconId(_friendName).trim()
        : AppStorage.getProfileIconId().trim();

    // Load icons once
    if (_loading) {
      _loadIcons();
    }
  }

  Future<void> _loadIcons() async {
    try {
      final manifestStr = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestStr);

      if (manifest is Map<String, dynamic>) {
        final keys = manifest.keys.toList();

        // Grab only: assets/icons/<id>.png
        final iconKeys = keys
            .where((k) => k.startsWith('assets/icons/') && k.endsWith('.png'))
            .toList();

        final ids = iconKeys
            .map((k) => k
                .replaceFirst('assets/icons/', '')
                .replaceFirst('.png', '')
                .trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        if (!mounted) return;
        setState(() {
          _iconIds = ids;
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // fallthrough
    }

    if (!mounted) return;
    setState(() {
      _iconIds = const [];
      _loading = false;
    });
  }

  String _title() {
    if (_forFriend) return "Pick an icon for $_friendName";
    return "Pick your icon";
  }

  Future<void> _save(String iconId) async {
    if (_forFriend) {
      await AppStorage.setFriendIconId(_friendName, iconId);
    } else {
      await AppStorage.setProfileIconId(iconId);
    }
  }

  Future<void> _clear() async {
    await _save('');
    if (!mounted) return;
    setState(() => _selectedId = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: KnowNoKnowTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: KnowNoKnowTheme.ink),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _title(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: KnowNoKnowTheme.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clear,
                      child: const Text(
                        "Clear",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),

              if (_loading) ...[
                const SizedBox(height: 40),
                const Center(child: CircularProgressIndicator()),
              ] else if (_iconIds.isEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: KnowNoKnowTheme.cardGradient,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: KnowNoKnowTheme.stroke, width: 1.2),
                    ),
                    child: const Text(
                      "No icons found in assets/icons.\n\nAdd PNGs to:\nassets/icons/<iconId>.png\n\nAnd make sure pubspec.yaml includes the assets folder.",
                      style: TextStyle(
                        color: KnowNoKnowTheme.ink,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _iconIds.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (_, i) {
                        final id = _iconIds[i];
                        final assetPath = 'assets/icons/$id.png';
                        final selected = id == _selectedId;

                        return GestureDetector(
                          onTap: () async {
                            await _save(id);
                            if (!mounted) return;
                            setState(() => _selectedId = id);
                            if (Navigator.canPop(context)) Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: selected
                                    ? KnowNoKnowTheme.primary
                                    : KnowNoKnowTheme.stroke,
                                width: selected ? 2.0 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                assetPath,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Center(
                                    child: Text(
                                      id.isNotEmpty ? id[0].toUpperCase() : "?",
                                      style: const TextStyle(
                                        color: KnowNoKnowTheme.ink,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
