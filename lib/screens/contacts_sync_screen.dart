import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_router.dart';
import '../auth/auth_service.dart';
import '../services/firestore_service.dart';
import '../storage.dart';
import '../theme/know_no_know_theme.dart';

class ContactsSyncScreen extends StatefulWidget {
const ContactsSyncScreen({super.key});

@override
State<ContactsSyncScreen> createState() => _ContactsSyncScreenState();
}

class _ContactsSyncScreenState extends State<ContactsSyncScreen> {
bool _loading = true;
bool _saving = false;
String? _error;

List<_LocalContact> _all = [];
List<_AppUserContact> _onApp = [];
List<_LocalContact> _notOnApp = [];

final Set<String> _selectedUids = {};
final Set<String> _selectedLocalKeys = {};

static const int minPick = AppStorage.minCircleMembersToUnlock;
static const bool kDevBypassContacts = true;

@override
void initState() {
super.initState();

debugPrint('🔥 CONTACT SCREEN INIT HIT');

WidgetsBinding.instance.addPostFrameCallback((_) {
_boot();
});
}

Future<void> _boot() async {
if (!mounted) return;

debugPrint('🔥 CONTACT SCREEN _boot START (NO CONTACTS MODE)');

try {
if (FirebaseAuth.instance.currentUser == null) {
debugPrint('🔥 NO FIREBASE USER — ENSURING SIGN IN');
await AuthService.ensureSignedIn();
debugPrint('🔥 SIGN IN COMPLETE');
} else {
debugPrint(
'🔥 FIREBASE USER EXISTS: ${FirebaseAuth.instance.currentUser?.uid}',
);
}

if (!mounted) return;

setState(() {
_loading = false;
_error = null;
_all = [];
_onApp = [];
_notOnApp = [];
});

debugPrint('🔥 CONTACT SCREEN _boot SUCCESS (NO CONTACTS MODE)');
} catch (e) {
debugPrint('🔥 CONTACT SCREEN _boot CRASH: $e');

if (!mounted) return;

setState(() {
_loading = false;
_error = 'Failed to load contacts screen. ($e)';
});
}
}

int get _selectedCount => _selectedUids.length + _selectedLocalKeys.length;
bool get _meetsMin => _selectedCount >= minPick;

void _toggleOnApp(_AppUserContact u) {
setState(() {
if (_selectedUids.contains(u.uid)) {
_selectedUids.remove(u.uid);
} else {
_selectedUids.add(u.uid);
}
_error = null;
});
}

void _toggleLocal(_LocalContact c) {
final key = '${c.name}|${c.phone}';

setState(() {
if (_selectedLocalKeys.contains(key)) {
_selectedLocalKeys.remove(key);
} else {
_selectedLocalKeys.add(key);
}
_error = null;
});
}

Future<void> _devSkip() async {
if (_saving) return;

setState(() {
_saving = true;
_error = null;
});

try {
if (FirebaseAuth.instance.currentUser == null) {
await AuthService.ensureSignedIn();
}

final fs = FirestoreService(AuthService.uid);
final circleId = await fs.ensureDefaultCircleId();

final seed = <CircleSeedMember>[
CircleSeedMember(
memberId: 'dev_1',
displayName: 'Test Friend 1',
onKetchUp: false,
phoneE164: '+15555550101',
),
CircleSeedMember(
memberId: 'dev_2',
displayName: 'Test Friend 2',
onKetchUp: false,
phoneE164: '+15555550102',
),
CircleSeedMember(
memberId: 'dev_3',
displayName: 'Test Friend 3',
onKetchUp: false,
phoneE164: '+15555550103',
),
CircleSeedMember(
memberId: 'dev_4',
displayName: 'Test Friend 4',
onKetchUp: false,
phoneE164: '+15555550104',
),
CircleSeedMember(
memberId: 'dev_5',
displayName: 'Test Friend 5',
onKetchUp: false,
phoneE164: '+15555550105',
),
];

await fs.addMembersBulk(circleId: circleId, members: seed);
await AppStorage.setContactsSynced(true);
await AppStorage.setAddFriendsDone(true);

if (!mounted) return;
Navigator.pushNamedAndRemoveUntil(
context,
AppRouter.circle,
(_) => false,
);
} catch (e) {
if (!mounted) return;
setState(() {
_error = 'Dev skip failed. ($e)';
});
} finally {
if (!mounted) return;
setState(() {
_saving = false;
});
}
}

Future<void> _continue() async {
if (_saving) return;

if (!kDevBypassContacts && !_meetsMin) {
setState(() {
_error = 'Pick at least $minPick people.';
});
return;
}

setState(() {
_saving = true;
_error = null;
});

try {
final fs = FirestoreService(AuthService.uid);
final circleId = await fs.ensureDefaultCircleId();

final members = <CircleSeedMember>[];

for (final u in _onApp) {
if (!_selectedUids.contains(u.uid)) continue;

members.add(
CircleSeedMember(
memberId: 'uid_${u.uid}',
displayName: u.displayName,
onKetchUp: true,
uid: u.uid,
username: u.username,
),
);
}

for (final c in _notOnApp) {
final key = '${c.name}|${c.phone}';
if (!_selectedLocalKeys.contains(key)) continue;

final e164 = FirestoreService.normalizePhone(c.phone);
final stable = e164.isNotEmpty
? 'phone_${e164.replaceAll('+', '')}'
: 'local_${c.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${c.name.hashCode.abs()}';

members.add(
CircleSeedMember(
memberId: stable,
displayName: c.name,
onKetchUp: false,
phoneE164: e164.isEmpty ? null : e164,
),
);
}

if (kDevBypassContacts && members.isEmpty) {
members.addAll([
CircleSeedMember(
memberId: 'dev_1',
displayName: 'Test Friend 1',
onKetchUp: false,
phoneE164: '+15555550101',
),
CircleSeedMember(
memberId: 'dev_2',
displayName: 'Test Friend 2',
onKetchUp: false,
phoneE164: '+15555550102',
),
CircleSeedMember(
memberId: 'dev_3',
displayName: 'Test Friend 3',
onKetchUp: false,
phoneE164: '+15555550103',
),
CircleSeedMember(
memberId: 'dev_4',
displayName: 'Test Friend 4',
onKetchUp: false,
phoneE164: '+15555550104',
),
CircleSeedMember(
memberId: 'dev_5',
displayName: 'Test Friend 5',
onKetchUp: false,
phoneE164: '+15555550105',
),
]);
}

await fs.addMembersBulk(circleId: circleId, members: members);
await AppStorage.setContactsSynced(true);
await AppStorage.setAddFriendsDone(true);

if (!mounted) return;
Navigator.pushNamedAndRemoveUntil(
context,
AppRouter.circle,
(_) => false,
);
} catch (e) {
if (!mounted) return;
setState(() {
_error = 'Failed to save. ($e)';
});
} finally {
if (!mounted) return;
setState(() {
_saving = false;
});
}
}

@override
Widget build(BuildContext context) {
final selected = _selectedCount;
final meetsMinUi = kDevBypassContacts ? true : _meetsMin;

return Scaffold(
backgroundColor: Colors.transparent,
appBar: AppBar(
title: const Text(
'CONTACTS',
style: TextStyle(
fontWeight: FontWeight.w900,
letterSpacing: 0.6,
),
),
actions: [
if (kDevBypassContacts)
TextButton(
onPressed: _saving ? null : _devSkip,
child: const Text(
'SKIP (DEV)',
style: TextStyle(fontWeight: FontWeight.w900),
),
),
],
),
body: Container(
decoration: const BoxDecoration(
image: DecorationImage(
image: AssetImage('assets/today_screen.jpg'),
fit: BoxFit.cover,
),
),
child: SafeArea(
child: Padding(
padding: const EdgeInsets.all(18),
child: _loading
? const Center(child: CircularProgressIndicator())
: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Pick at least 5 people',
style: TextStyle(
color: KnowNoKnowTheme.ink,
fontWeight: FontWeight.w900,
fontSize: 26,
),
),
const SizedBox(height: 6),
Text(
kDevBypassContacts
? 'DEV MODE: You can skip contacts while building.'
: 'You need at least $minPick people to unlock your daily mystery call.',
style: const TextStyle(
color: KnowNoKnowTheme.mutedInk,
fontWeight: FontWeight.w900,
),
),
const SizedBox(height: 10),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 10,
),
decoration: BoxDecoration(
color: KnowNoKnowTheme.panel,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: KnowNoKnowTheme.stroke,
width: 1.2,
),
),
child: Row(
children: [
const Icon(
Icons.check_circle_rounded,
color: Colors.black,
size: 20,
),
const SizedBox(width: 10),
Expanded(
child: Text(
kDevBypassContacts
? 'Selected: $selected'
: 'Selected: $selected / $minPick',
style: const TextStyle(
color: KnowNoKnowTheme.ink,
fontWeight: FontWeight.w900,
),
),
),
Icon(
meetsMinUi
? Icons.lock_open_rounded
: Icons.lock_rounded,
color: meetsMinUi
? Colors.black
: KnowNoKnowTheme.mutedInk,
),
],
),
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
const SizedBox(height: 14),
Expanded(
child: ListView(
physics: const BouncingScrollPhysics(),
children: [
if (_onApp.isNotEmpty) ...[
const _SectionTitle('Already on Know No Know'),
const SizedBox(height: 8),
..._onApp.map((u) {
final sel = _selectedUids.contains(u.uid);
return _SelectableUserTile(
u: u,
selected: sel,
onTap: () => _toggleOnApp(u),
);
}),
const SizedBox(height: 14),
],
const _SectionTitle('From your contacts'),
const SizedBox(height: 8),
..._notOnApp.map((c) {
final key = '${c.name}|${c.phone}';
final sel = _selectedLocalKeys.contains(key);
return _SelectableLocalTile(
c: c,
selected: sel,
onTap: () => _toggleLocal(c),
);
}),
if (kDevBypassContacts && _all.isEmpty)
const Padding(
padding: EdgeInsets.only(top: 6),
child: Text(
'No contacts loaded in dev mode yet.',
style: TextStyle(fontWeight: FontWeight.w800),
),
),
],
),
),
const SizedBox(height: 12),
SizedBox(
width: double.infinity,
height: 54,
child: ElevatedButton(
onPressed: _saving ? null : _continue,
style: ElevatedButton.styleFrom(
backgroundColor: Colors.black,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(18),
),
),
child: Text(
_saving ? 'SAVING...' : 'CONTINUE',
style: const TextStyle(
fontWeight: FontWeight.w900,
letterSpacing: 0.8,
),
),
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

class _SectionTitle extends StatelessWidget {
const _SectionTitle(this.text);

final String text;

@override
Widget build(BuildContext context) {
return Text(
text,
style: const TextStyle(
fontWeight: FontWeight.w900,
color: Colors.black87,
),
);
}
}

class _SelectableUserTile extends StatelessWidget {
const _SelectableUserTile({
required this.u,
required this.selected,
required this.onTap,
});

final _AppUserContact u;
final bool selected;
final VoidCallback onTap;

@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.only(bottom: 8),
child: ListTile(
onTap: onTap,
tileColor: Colors.white.withOpacity(0.65),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
contentPadding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 4,
),
leading: CircleAvatar(
backgroundColor: Colors.black.withOpacity(0.08),
child: Text(
u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
style: const TextStyle(
fontWeight: FontWeight.w900,
color: Colors.black,
),
),
),
title: Text(
u.displayName,
style: const TextStyle(fontWeight: FontWeight.w900),
),
subtitle: Text('@${u.username}'),
trailing: Icon(
selected ? Icons.check_circle : Icons.circle_outlined,
color: Colors.black,
),
),
);
}
}

class _SelectableLocalTile extends StatelessWidget {
const _SelectableLocalTile({
required this.c,
required this.selected,
required this.onTap,
});

final _LocalContact c;
final bool selected;
final VoidCallback onTap;

@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.only(bottom: 8),
child: ListTile(
onTap: onTap,
tileColor: Colors.white.withOpacity(0.65),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
contentPadding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 4,
),
leading: CircleAvatar(
backgroundColor: Colors.black.withOpacity(0.08),
child: Text(
c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
style: const TextStyle(
fontWeight: FontWeight.w900,
color: Colors.black,
),
),
),
title: Text(
c.name,
style: const TextStyle(fontWeight: FontWeight.w900),
),
subtitle: Text(c.phone),
trailing: Icon(
selected ? Icons.check_circle : Icons.circle_outlined,
color: Colors.black,
),
),
);
}
}

class _LocalContact {
const _LocalContact({
required this.name,
required this.phone,
});

final String name;
final String phone;
}

class _AppUserContact {
const _AppUserContact({
required this.uid,
required this.displayName,
required this.username,
});

final String uid;
final String displayName;
final String username;
}