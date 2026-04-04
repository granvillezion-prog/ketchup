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

// Keep this true until the iOS contacts crash is fully isolated and fixed.
static const bool kDevBypassContacts = true;

@override
void initState() {
super.initState();

debugPrint('🔥 CONTACT SCREEN INIT HIT');

if (kDevBypassContacts) {
debugPrint('🔥 DEV BYPASS ACTIVE — SKIPPING CONTACTS BOOT');
_loading = false;
return;
}

WidgetsBinding.instance.addPostFrameCallback((_) {
_boot();
});
}

Future<void> _boot() async {
if (!mounted) return;

debugPrint('🔥 CONTACT SCREEN _boot START (NO CONTACTS MODE)');

try {
setState(() {
_loading = false;
_error = null;
_all = [];
_onApp = [];
_notOnApp = [];
});

debugPrint('🔥 CONTACT SCREEN _boot SUCCESS (NO CONTACTS MODE)');
} catch (e) {
debugPrint('🔥 CONTACT SCREEN _boot OUTER CRASH: $e');

if (!mounted) return;
setState(() {
_loading = false;
_error = 'Failed to load contacts screen. ($e)';
});
}
}

bool permitted = false;

try {
debugPrint('🔥 REQUESTING CONTACT PERMISSION...');
permitted = await FlutterContacts.requestPermission();
debugPrint('🔥 CONTACT PERMISSION RESULT: $permitted');
} catch (e) {
debugPrint('🔥 PERMISSION CRASH: $e');

if (!mounted) return;
setState(() {
_loading = false;
_error = 'Permission request crashed: $e';
});
return;
}

if (!permitted) {
debugPrint('🔥 PERMISSION DENIED — STOPPING FLOW');

if (!mounted) return;
setState(() {
_loading = false;
_error = 'Contacts permission denied.';
});
return;
}

List<Contact> contacts = [];

try {
debugPrint('🔥 FETCHING CONTACTS...');
contacts = await FlutterContacts.getContacts(withProperties: true);
debugPrint('🔥 CONTACTS LOADED: ${contacts.length}');
} catch (e) {
debugPrint('🔥 CONTACT FETCH CRASH: $e');

if (!mounted) return;
setState(() {
_loading = false;
_error = 'Failed to load contacts: $e';
});
return;
}

final locals = <_LocalContact>[];

for (final c in contacts) {
final name = [c.name.first, c.name.last]
.where((x) => x.trim().isNotEmpty)
.join(' ')
.trim();

final phones = c.phones.map((p) => p.number).toList();
if (name.isEmpty || phones.isEmpty) continue;

locals.add(_LocalContact(name: name, phones: phones));
}

debugPrint('🔥 LOCAL CONTACTS AFTER FILTER: ${locals.length}');

final phoneSet = <String>{};
for (final lc in locals) {
for (final raw in lc.phones) {
final e164 = _toE164Guess(raw);
if (e164.isNotEmpty) phoneSet.add(e164);
}
}

debugPrint('🔥 NORMALIZED PHONE COUNT: ${phoneSet.length}');

final fs = FirestoreService(AuthService.uid);
final phoneToUid = await fs.lookupExistingUsersByPhones(phoneSet.toList());
final uids = phoneToUid.values.toSet().toList();
final profiles = await fs.getPublicProfilesByUids(uids);
final uidToProfile = {for (final p in profiles) p.uid: p};

final onApp = <_AppUserContact>[];
final usedUid = <String>{};

for (final entry in phoneToUid.entries) {
final uid = entry.value;
if (usedUid.contains(uid)) continue;

final prof = uidToProfile[uid];
if (prof == null) continue;

usedUid.add(uid);
onApp.add(
_AppUserContact(
uid: uid,
displayName:
prof.displayName.isEmpty ? 'Unknown' : prof.displayName,
username: prof.username,
),
);
}

onApp.sort(
(a, b) =>
a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
);

final notOn = <_LocalContact>[];
for (final lc in locals) {
var anyMatch = false;
for (final raw in lc.phones) {
final e164 = _toE164Guess(raw);
if (e164.isNotEmpty && phoneToUid.containsKey(e164)) {
anyMatch = true;
break;
}
}
if (!anyMatch) notOn.add(lc);
}

notOn.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

debugPrint('🔥 ON APP COUNT: ${onApp.length}');
debugPrint('🔥 NOT ON APP COUNT: ${notOn.length}');

if (!mounted) return;
setState(() {
_all = locals;
_onApp = onApp;
_notOnApp = notOn;
_loading = false;
});

debugPrint('🔥 CONTACT SCREEN _boot SUCCESS');
} catch (e) {
debugPrint('🔥 CONTACT SCREEN _boot OUTER CRASH: $e');

if (!mounted) return;
setState(() {
_loading = false;
_error = 'Failed to sync contacts. ($e)';
});
}
}

String _toE164Guess(String raw) {
final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
if (d.length == 10) return '+1$d';
if (d.length == 11 && d.startsWith('1')) return '+$d';
if (raw.trim().startsWith('+') && d.length >= 8) return '+$d';
return '';
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

String _bestPhoneKey(_LocalContact c) {
for (final raw in c.phones) {
final e164 = _toE164Guess(raw);
if (e164.isNotEmpty) return e164;
}
return '';
}

void _toggleLocal(_LocalContact c) {
final best = _bestPhoneKey(c);
final key = '${c.name}|$best';

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
setState(() => _error = 'Dev skip failed. ($e)');
} finally {
if (!mounted) return;
setState(() => _saving = false);
}
}

Future<void> _continue() async {
if (_saving) return;

if (!kDevBypassContacts && !_meetsMin) {
setState(() => _error = 'Pick at least $minPick people.');
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
final best = _bestPhoneKey(c);
final key = '${c.name}|$best';
if (!_selectedLocalKeys.contains(key)) continue;

final e164 = FirestoreService.normalizePhone(best);
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
setState(() => _error = 'Failed to save. ($e)');
} finally {
if (!mounted) return;
setState(() => _saving = false);
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
style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
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
final key = '${c.name}|${_bestPhoneKey(c)}';
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
subtitle: Text(c.phones.isNotEmpty ? c.phones.first : ''),
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
required this.phones,
});

final String name;
final List<String> phones;
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