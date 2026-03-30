import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_router.dart';
import '../auth/auth_service.dart';
import '../services/firestore_service.dart';
import '../storage.dart';
import 'profile_hub_screen.dart';

class CircleScreen extends StatefulWidget {
const CircleScreen({super.key});

@override
State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen>
with WidgetsBindingObserver {
final TextEditingController _add = TextEditingController();

FirestoreService? _db;
String? _selectedCircleId;
String? _error;

static const bool kDevMode = true;
static const Color _iosPurple = Color(0xFFB75AFF);
static const Color _friendBoxColor = Color(0xFFE354FE);

final List<_UserHit> _userHits = <_UserHit>[];
bool _searching = false;
Timer? _debounce;
final Set<String> _addingUids = <String>{};
final Set<String> _requestingUids = <String>{};

_FriendProfile? _openProfile;

CameraController? _cameraController;
bool _cameraReady = false;
bool _cameraInitializing = false;

@override
void initState() {
super.initState();
WidgetsBinding.instance.addObserver(this);
_init();
_add.addListener(_onQueryChanged);
_initFrontCamera();
}

@override
void dispose() {
WidgetsBinding.instance.removeObserver(this);
_debounce?.cancel();
_add.removeListener(_onQueryChanged);
_add.dispose();
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

Future<void> _init() async {
await AuthService.ensureSignedIn();

final uid = FirebaseAuth.instance.currentUser?.uid;
if (uid == null) {
if (!mounted) return;
setState(() => _error = 'Not signed in yet.');
return;
}

_db = FirestoreService(uid);
await _bootstrap();
}

Future<void> _bootstrap() async {
await _db!.ensureHasAtLeastOneCircle();

final saved = AppStorage.getSelectedCircleId();
if (!mounted) return;
setState(() => _selectedCircleId = saved);
}

String _initials(String name) {
final parts =
name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
if (parts.isEmpty) return '?';
if (parts.length == 1) {
final s = parts.first;
return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
}
return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

Color _avatarBg(String name) {
final h = name.hashCode.abs() % 6;
switch (h) {
case 0:
return Colors.white.withOpacity(0.22);
case 1:
return Colors.black.withOpacity(0.10);
case 2:
return Colors.white.withOpacity(0.16);
case 3:
return Colors.black.withOpacity(0.06);
case 4:
return Colors.white.withOpacity(0.12);
default:
return Colors.black.withOpacity(0.08);
}
}

Future<void> _selectCircle(String id) async {
setState(() {
_selectedCircleId = id;
_error = null;
_openProfile = null;
});
await AppStorage.setSelectedCircleId(id);
}

Future<void> _addMember(
List<CircleMember> currentMembers,
String circleId,
) async {
final raw = _add.text.trim();
if (raw.isEmpty) return;

setState(() {
_error = 'Search and tap ADD next to a real user.';
});

if (_userHits.isEmpty) return;

final exact = _userHits.where((h) {
return h.displayName.toLowerCase() == raw.toLowerCase() ||
h.username.toLowerCase() == raw.toLowerCase().replaceAll('@', '');
}).toList();

if (exact.length == 1) {
await _addRealUserToCircle(
hit: exact.first,
currentMembers: currentMembers,
circleId: circleId,
);
}
}

Future<void> _addRealUserToCircle({
required _UserHit hit,
required List<CircleMember> currentMembers,
required String circleId,
}) async {
if (_addingUids.contains(hit.uid)) return;

final exists = currentMembers.any(
(m) => (m.uid ?? '').trim() == hit.uid,
);
if (exists) {
setState(() => _error = 'Already in this circle.');
return;
}

setState(() {
_addingUids.add(hit.uid);
_error = null;
});

try {
await _db!.addMembersBulk(
circleId: circleId,
members: [
CircleSeedMember(
memberId: 'uid_${hit.uid}',
displayName: hit.displayName.isEmpty ? hit.username : hit.displayName,
uid: hit.uid,
username: hit.username,
onKetchUp: true,
),
],
);

_toast(
'Added ${hit.displayName.isEmpty ? '@${hit.username}' : hit.displayName}',
);

setState(() {
_add.clear();
_userHits.clear();
});
} catch (e) {
setState(() => _error = 'Couldn’t add. ($e)');
} finally {
if (!mounted) return;
setState(() => _addingUids.remove(hit.uid));
}
}

Future<void> _removeMember(String circleId, String memberId) async {
try {
await _db!.removeMember(circleId: circleId, memberId: memberId);
} catch (e) {
setState(() => _error = 'Couldn’t remove. ($e)');
}
}

void _toast(String msg) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w800)),
behavior: SnackBarBehavior.floating,
backgroundColor: Colors.black.withOpacity(0.88),
),
);
}

Future<void> _syncActiveCircleToLocal(List<CircleMember> members) async {
final names = members
.map((m) => m.displayName.trim())
.where((s) => s.isNotEmpty)
.toList();
await AppStorage.setCircle(names);
}

void _continueIfValid(int realAppCount) {
if (realAppCount < AppStorage.minCircleMembersToUnlock) {
setState(() {
_error =
'Add at least ${AppStorage.minCircleMembersToUnlock} real app users to unlock your daily call.';
});
return;
}

AppStorage.setAddFriendsDone(true);
Navigator.pushNamedAndRemoveUntil(
context,
AppRouter.today,
(_) => false,
);
}

void _showDevMessage() {
setState(() {
_error = 'Dev fake friends are disabled. Only real users count now.';
});
}

static String _cleanQuery(String s) {
final lowered = s.trim().toLowerCase();
final cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9\s@]'), ' ');
return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

void _onQueryChanged() {
_debounce?.cancel();
_debounce = Timer(const Duration(milliseconds: 220), () async {
if (!mounted) return;

final raw = _cleanQuery(_add.text);
if (raw.isEmpty) {
setState(() {
_userHits.clear();
_searching = false;
_error = null;
});
return;
}

final q = raw.startsWith('@') ? raw.substring(1) : raw;
if (q.length < 2) {
setState(() {
_userHits.clear();
_searching = false;
});
return;
}

if (raw.startsWith('@')) {
await _searchByUsernamePrefix(q);
} else {
await _searchByNameOrUsername(raw);
}
});
}

Future<void> _searchByUsernamePrefix(String prefix) async {
setState(() => _searching = true);

try {
final snap = await FirebaseFirestore.instance
.collection('usernames')
.orderBy(FieldPath.documentId)
.startAt([prefix.toLowerCase()])
.endAt(['${prefix.toLowerCase()}\uf8ff'])
.limit(10)
.get();

final hits = <_UserHit>[];
for (final d in snap.docs) {
final data = d.data();
final uid = (data['uid'] ?? '').toString();
final username = d.id;
final displayName = (data['displayName'] ?? '').toString();

if (uid.isEmpty) continue;
if (uid == FirebaseAuth.instance.currentUser?.uid) continue;

hits.add(
_UserHit(uid: uid, username: username, displayName: displayName),
);
}

if (!mounted) return;
setState(() {
_userHits
..clear()
..addAll(hits);
_searching = false;
});
} catch (_) {
if (!mounted) return;
setState(() {
_userHits.clear();
_searching = false;
});
}
}

Future<void> _searchByNameOrUsername(String query) async {
setState(() => _searching = true);

try {
final cleaned = _cleanQuery(query);
final parts = cleaned.split(' ').where((p) => p.isNotEmpty).toList();
final token = parts.isEmpty ? cleaned : parts.first;

final snap = await FirebaseFirestore.instance
.collection('publicProfiles')
.where('searchTokens', arrayContains: token)
.limit(16)
.get();

final qLower = cleaned.toLowerCase();

final hits = <_UserHit>[];
for (final d in snap.docs) {
final data = d.data();
final uid = d.id;
if (uid == FirebaseAuth.instance.currentUser?.uid) continue;

final displayName = (data['displayName'] ?? '').toString();
final username = (data['username'] ?? '').toString();

final dnLower =
(data['displayNameLower'] ?? displayName.toLowerCase()).toString();
final unLower =
(data['usernameLower'] ?? username.toLowerCase()).toString();

final ok = parts.every((p) => dnLower.contains(p) || unLower.contains(p));
if (!ok) continue;

hits.add(
_UserHit(uid: uid, username: username, displayName: displayName),
);
}

hits.sort((a, b) {
final aScore = _scoreHit(a, qLower);
final bScore = _scoreHit(b, qLower);
return bScore.compareTo(aScore);
});

if (!mounted) return;
setState(() {
_userHits
..clear()
..addAll(hits.take(10));
_searching = false;
});
} catch (_) {
if (!mounted) return;
setState(() {
_userHits.clear();
_searching = false;
});
}
}

int _scoreHit(_UserHit h, String qLower) {
final dn = h.displayName.toLowerCase();
final un = h.username.toLowerCase();
var s = 0;
if (dn == qLower) s += 50;
if (un == qLower) s += 50;
if (dn.startsWith(qLower)) s += 20;
if (un.startsWith(qLower)) s += 18;
if (dn.contains(qLower)) s += 10;
if (un.contains(qLower)) s += 8;
return s;
}

Future<void> _sendFriendRequest(_UserHit hit) async {
final fromUid = FirebaseAuth.instance.currentUser?.uid;
if (fromUid == null) return;
if (_requestingUids.contains(hit.uid)) return;

setState(() {
_requestingUids.add(hit.uid);
_error = null;
});

try {
final now = FieldValue.serverTimestamp();

final incomingRef = FirebaseFirestore.instance
.collection('friend_requests')
.doc(hit.uid)
.collection('incoming')
.doc(fromUid);

final outgoingRef = FirebaseFirestore.instance
.collection('friend_requests')
.doc(fromUid)
.collection('outgoing')
.doc(hit.uid);

await FirebaseFirestore.instance.runTransaction((tx) async {
tx.set(incomingRef, {
'fromUid': fromUid,
'toUid': hit.uid,
'createdAt': now,
'status': 'pending',
});
tx.set(outgoingRef, {
'fromUid': fromUid,
'toUid': hit.uid,
'createdAt': now,
'status': 'pending',
});
});

_toast('Friend request sent to @${hit.username}');
} catch (e) {
setState(() => _error = 'Couldn’t send request. ($e)');
} finally {
if (!mounted) return;
setState(() => _requestingUids.remove(hit.uid));
}
}

void _openFriendProfile({
required String circleId,
required CircleMember member,
}) {
setState(() {
_openProfile = _FriendProfile(circleId: circleId, member: member);
});
}

void _closeFriendProfile() {
setState(() => _openProfile = null);
}

Widget _PrimaryDoneButton({
required VoidCallback onPressed,
required int realAppCount,
}) {
final need = AppStorage.minCircleMembersToUnlock;
final done = realAppCount >= need;

return SizedBox(
width: double.infinity,
height: 54,
child: ElevatedButton(
onPressed: onPressed,
style: ElevatedButton.styleFrom(
backgroundColor: Colors.black.withOpacity(0.72),
foregroundColor: Colors.white,
elevation: 0,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(18),
side: BorderSide(color: Colors.white.withOpacity(0.08)),
),
),
child: Text(
done ? 'DONE' : 'ADD ${need - realAppCount} MORE',
style: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.w900,
letterSpacing: 0.6,
),
),
),
);
}

Widget _AddActionButton({
required bool busy,
required String label,
required VoidCallback onPressed,
}) {
return SizedBox(
height: 36,
child: OutlinedButton(
onPressed: busy ? null : onPressed,
style: OutlinedButton.styleFrom(
foregroundColor: Colors.white,
backgroundColor: Colors.white.withOpacity(0.08),
side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.1),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
padding: const EdgeInsets.symmetric(horizontal: 12),
),
child: Text(
busy ? 'WORKING…' : label,
style: const TextStyle(
fontWeight: FontWeight.w900,
letterSpacing: 0.4,
fontSize: 12,
),
),
),
);
}

Widget _DevSeedButton({
required bool disabled,
required VoidCallback onPressed,
}) {
return SizedBox(
width: double.infinity,
height: 48,
child: OutlinedButton(
onPressed: disabled ? null : onPressed,
style: OutlinedButton.styleFrom(
foregroundColor: Colors.white,
side: BorderSide(
color: Colors.white.withOpacity(0.14),
width: 1.1,
),
backgroundColor: Colors.white.withOpacity(0.08),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
),
child: const Text(
'DEV NOTE • REAL USERS ONLY',
style: TextStyle(
fontWeight: FontWeight.w900,
letterSpacing: 0.3,
),
),
),
);
}

Widget _circleTabs({
required List<UserCircle> circles,
required String selectedId,
}) {
return SizedBox(
height: 44,
child: ListView.separated(
scrollDirection: Axis.horizontal,
itemCount: circles.length,
separatorBuilder: (_, __) => const SizedBox(width: 10),
itemBuilder: (context, i) {
final c = circles[i];
final selected = c.id == selectedId;

return GestureDetector(
onTap: () => _selectCircle(c.id),
child: ClipRRect(
borderRadius: BorderRadius.circular(999),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 10,
),
decoration: BoxDecoration(
color: selected
? Colors.white.withOpacity(0.16)
: Colors.black.withOpacity(0.18),
borderRadius: BorderRadius.circular(999),
border: Border.all(
color: Colors.white.withOpacity(0.10),
width: 1.0,
),
),
child: Text(
c.name,
style: TextStyle(
color: Colors.white.withOpacity(selected ? 1 : 0.82),
fontWeight: FontWeight.w900,
),
),
),
),
),
);
},
),
);
}

@override
Widget build(BuildContext context) {
if (_db == null) {
return Scaffold(
backgroundColor: Colors.black,
body: Stack(
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
child: Container(color: Colors.black.withOpacity(0.50)),
),
SafeArea(
child: Center(
child: Text(
_error ?? 'Loading auth…',
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
),
),
),
),
],
),
);
}

return Scaffold(
backgroundColor: Colors.black,
body: Stack(
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
child: Container(color: Colors.black.withOpacity(0.50)),
),
StreamBuilder<List<UserCircle>>(
stream: _db!.streamCircles(),
builder: (context, circlesSnap) {
final circlesLoading = !circlesSnap.hasData;
final allCircles = circlesSnap.data ?? const <UserCircle>[];

if (circlesLoading) {
return const SafeArea(
child: Center(
child: CircularProgressIndicator(color: Colors.white),
),
);
}

if (allCircles.isEmpty) {
return const SafeArea(
child: Center(
child: Text(
'Creating Circle 1…',
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
),
),
),
);
}

final circles = allCircles;
final fallbackId = circles.first.id;
final selectedId = (_selectedCircleId != null &&
circles.any((c) => c.id == _selectedCircleId))
? _selectedCircleId!
: fallbackId;

if (_selectedCircleId != selectedId) {
WidgetsBinding.instance.addPostFrameCallback((_) {
_selectCircle(selectedId);
});
}

return StreamBuilder<List<CircleMember>>(
stream: _db!.streamMembers(selectedId),
builder: (context, membersSnap) {
final membersLoading = !membersSnap.hasData;
final members = membersSnap.data ?? const <CircleMember>[];
final open = _openProfile;

final memberCount = members.length;
final realAppCount = members
.where((m) => (m.uid ?? '').trim().isNotEmpty && m.onKetchUp)
.length;

final need = AppStorage.minCircleMembersToUnlock;
final ready = realAppCount >= need;

if (membersSnap.hasData) {
WidgetsBinding.instance.addPostFrameCallback((_) {
_syncActiveCircleToLocal(members);
});
}

return SafeArea(
bottom: false,
child: Column(
children: [
Padding(
padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
child: Row(
children: [
const Text(
'Circle',
style: TextStyle(
fontSize: 28,
fontWeight: FontWeight.w900,
color: Colors.white,
letterSpacing: -0.2,
),
),
const Spacer(),
if (kDevMode)
Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 6,
),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.22),
borderRadius: BorderRadius.circular(999),
border: Border.all(
color: Colors.white.withOpacity(0.10),
),
),
child: const Text(
'DEV',
style: TextStyle(
fontWeight: FontWeight.w900,
color: Colors.white,
),
),
),
const SizedBox(width: 10),
IconButton(
tooltip: 'Profile',
onPressed: () {
Navigator.push(
context,
CupertinoPageRoute<void>(
builder: (_) => const ProfileHubScreen(),
),
);
},
icon: const Icon(
CupertinoIcons.person_crop_circle,
color: Colors.white,
),
),
],
),
),
Padding(
padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
child: Align(
alignment: Alignment.centerLeft,
child: Text(
'Only real app users count. Add at least $need real users to unlock your daily call.',
style: TextStyle(
color: Colors.white.withOpacity(0.68),
fontWeight: FontWeight.w700,
fontSize: 13,
),
),
),
),
Padding(
padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
child: ClipRRect(
borderRadius: BorderRadius.circular(20),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
child: Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 12,
),
decoration: BoxDecoration(
color: ready
? Colors.white.withOpacity(0.12)
: _iosPurple.withOpacity(0.18),
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: Colors.white.withOpacity(0.08),
),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Expanded(
child: Text(
ready
? 'Setup unlocked • $realAppCount/$need real users'
: '$realAppCount/$need real users • add ${need - realAppCount} more',
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
),
),
),
Icon(
ready
? Icons.lock_open_rounded
: Icons.lock_rounded,
color: Colors.white,
),
],
),
const SizedBox(height: 8),
Text(
'Total members saved: $memberCount',
style: TextStyle(
color: Colors.white.withOpacity(0.72),
fontWeight: FontWeight.w800,
fontSize: 12,
),
),
],
),
),
),
),
),
Padding(
padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
child: ClipRRect(
borderRadius: BorderRadius.circular(18),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
child: TextField(
controller: _add,
textInputAction: TextInputAction.done,
onSubmitted: (_) => _addMember(members, selectedId),
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w800,
),
decoration: InputDecoration(
hintText: 'Search real users',
hintStyle: TextStyle(
color: Colors.white.withOpacity(0.45),
fontWeight: FontWeight.w800,
),
filled: true,
fillColor: Colors.white.withOpacity(0.08),
contentPadding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 14,
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: BorderSide(
color: Colors.white.withOpacity(0.08),
),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(18),
borderSide: BorderSide(
color: _iosPurple.withOpacity(0.95),
width: 1.6,
),
),
suffixIcon: _searching
? const Padding(
padding: EdgeInsets.all(12),
child: SizedBox(
width: 18,
height: 18,
child: CircularProgressIndicator(
strokeWidth: 2,
color: Colors.white,
),
),
)
: (_add.text.trim().isNotEmpty
? IconButton(
onPressed: () {
_add.clear();
setState(() {
_userHits.clear();
_searching = false;
_error = null;
});
},
icon: const Icon(
Icons.close,
color: Colors.white,
),
)
: null),
),
),
),
),
),
if (_error != null)
Padding(
padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
child: Align(
alignment: Alignment.centerLeft,
child: Text(
_error!,
style: const TextStyle(
color: _iosPurple,
fontWeight: FontWeight.w900,
),
),
),
),
Padding(
padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
child: _circleTabs(
circles: circles,
selectedId: selectedId,
),
),
if (kDevMode)
Padding(
padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
child: _DevSeedButton(
disabled: membersLoading,
onPressed: _showDevMessage,
),
),
Expanded(
child: membersLoading
? const Center(
child: CircularProgressIndicator(
color: Colors.white,
),
)
: (open != null)
? _FriendProfileView(
profile: open,
friendBoxColor: _friendBoxColor,
onBack: _closeFriendProfile,
onUnfriend: () async {
await _removeMember(
open.circleId,
open.member.id,
);
if (!mounted) return;
_toast(
'Removed ${open.member.displayName}',
);
_closeFriendProfile();
},
)
: members.isEmpty
? const _EmptyMembers()
: ListView(
padding: const EdgeInsets.fromLTRB(
18,
0,
18,
10,
),
children: [
Text(
'IN YOUR CIRCLE',
style: TextStyle(
fontWeight: FontWeight.w900,
color:
Colors.white.withOpacity(0.65),
letterSpacing: 0.8,
fontSize: 12,
),
),
const SizedBox(height: 12),
...members.map((m) {
final nm = m.displayName;
return Padding(
padding: const EdgeInsets.only(
bottom: 14,
),
child: _MemberCell(
name: nm,
initials: _initials(nm),
avatarBg: _avatarBg(nm),
onKetchUp: m.onKetchUp,
onTap: () => _openFriendProfile(
circleId: selectedId,
member: m,
),
),
);
}),
],
),
),
if (_userHits.isNotEmpty)
Container(
width: double.infinity,
margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.68),
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: Colors.white.withOpacity(0.08),
),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'SEARCH RESULTS',
style: TextStyle(
fontWeight: FontWeight.w900,
color: Colors.white,
letterSpacing: 0.8,
),
),
const SizedBox(height: 12),
..._userHits.map((h) {
final addBusy = _addingUids.contains(h.uid);
final requestBusy =
_requestingUids.contains(h.uid);

return Padding(
padding: const EdgeInsets.only(bottom: 10),
child: Row(
children: [
CircleAvatar(
radius: 24,
backgroundColor: _friendBoxColor,
child: Text(
_initials(
h.displayName.isEmpty
? h.username
: h.displayName,
),
style: const TextStyle(
fontWeight: FontWeight.w900,
color: Colors.white,
),
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
h.displayName.isEmpty
? '@${h.username}'
: h.displayName,
style: const TextStyle(
fontWeight: FontWeight.w900,
color: Colors.white,
fontSize: 16,
),
),
const SizedBox(height: 2),
Text(
'@${h.username}',
style: TextStyle(
fontWeight: FontWeight.w900,
color: Colors.white
.withOpacity(0.72),
fontSize: 12,
),
),
],
),
),
_AddActionButton(
busy: addBusy,
label: 'ADD',
onPressed: () => _addRealUserToCircle(
hit: h,
currentMembers: members,
circleId: selectedId,
),
),
const SizedBox(width: 8),
_AddActionButton(
busy: requestBusy,
label: 'REQUEST',
onPressed: () => _sendFriendRequest(h),
),
],
),
);
}),
],
),
),
Padding(
padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
child: _PrimaryDoneButton(
onPressed: () => _continueIfValid(realAppCount),
realAppCount: realAppCount,
),
),
],
),
);
},
);
},
),
],
),
);
}
}

class _UserHit {
const _UserHit({
required this.uid,
required this.username,
required this.displayName,
});

final String uid;
final String username;
final String displayName;
}

class _FriendProfile {
const _FriendProfile({
required this.circleId,
required this.member,
});

final String circleId;
final CircleMember member;
}

class _MemberCell extends StatelessWidget {
const _MemberCell({
required this.name,
required this.initials,
required this.avatarBg,
required this.onKetchUp,
required this.onTap,
});

final String name;
final String initials;
final Color avatarBg;
final bool onKetchUp;
final VoidCallback onTap;

@override
Widget build(BuildContext context) {
final subtitle = onKetchUp ? 'Real app user' : 'Legacy placeholder';

return ClipRRect(
borderRadius: BorderRadius.circular(20),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
child: Material(
color: Colors.white.withOpacity(0.10),
borderRadius: BorderRadius.circular(20),
child: InkWell(
borderRadius: BorderRadius.circular(20),
onTap: onTap,
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
child: Row(
children: [
CircleAvatar(
radius: 24,
backgroundColor: avatarBg,
child: Text(
initials,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
),
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
name,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
fontSize: 16,
),
),
const SizedBox(height: 2),
Text(
subtitle,
style: TextStyle(
color: Colors.white.withOpacity(0.6),
fontWeight: FontWeight.w800,
fontSize: 12,
),
),
],
),
),
const Icon(
Icons.chevron_right_rounded,
color: Colors.white,
),
],
),
),
),
),
),
);
}
}

class _FriendProfileView extends StatelessWidget {
const _FriendProfileView({
required this.profile,
required this.friendBoxColor,
required this.onBack,
required this.onUnfriend,
});

final _FriendProfile profile;
final Color friendBoxColor;
final VoidCallback onBack;
final Future<void> Function() onUnfriend;

String _initials(String name) {
final parts =
name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
if (parts.isEmpty) return '?';
if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

@override
Widget build(BuildContext context) {
final member = profile.member;

return ListView(
padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
children: [
TextButton.icon(
onPressed: onBack,
icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
label: const Text(
'Back',
style: TextStyle(
fontWeight: FontWeight.w900,
color: Colors.white,
),
),
),
const SizedBox(height: 8),
ClipRRect(
borderRadius: BorderRadius.circular(24),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
child: Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.10),
borderRadius: BorderRadius.circular(24),
border: Border.all(color: Colors.white.withOpacity(0.08)),
),
child: Column(
children: [
CircleAvatar(
radius: 36,
backgroundColor: friendBoxColor,
child: Text(
_initials(member.displayName),
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
fontSize: 24,
),
),
),
const SizedBox(height: 14),
Text(
member.displayName,
textAlign: TextAlign.center,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
fontSize: 22,
),
),
const SizedBox(height: 6),
Text(
member.onKetchUp ? 'Real app user' : 'Legacy placeholder',
style: TextStyle(
color: Colors.white.withOpacity(0.6),
fontWeight: FontWeight.w800,
),
),
if ((member.uid ?? '').trim().isNotEmpty) ...[
const SizedBox(height: 6),
Text(
'UID connected',
style: TextStyle(
color: Colors.white.withOpacity(0.75),
fontWeight: FontWeight.w900,
fontSize: 12,
),
),
],
const SizedBox(height: 20),
SizedBox(
width: double.infinity,
height: 52,
child: ElevatedButton(
onPressed: onUnfriend,
style: ElevatedButton.styleFrom(
backgroundColor: Colors.black.withOpacity(0.72),
foregroundColor: Colors.white,
elevation: 0,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(18),
side: BorderSide(
color: Colors.white.withOpacity(0.08),
),
),
),
child: const Text(
'REMOVE FROM CIRCLE',
style: TextStyle(
fontWeight: FontWeight.w900,
letterSpacing: 0.6,
),
),
),
),
],
),
),
),
),
],
);
}
}

class _EmptyMembers extends StatelessWidget {
const _EmptyMembers();

@override
Widget build(BuildContext context) {
return ListView(
padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
children: [
ClipRRect(
borderRadius: BorderRadius.circular(22),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
child: Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.10),
borderRadius: BorderRadius.circular(22),
border: Border.all(color: Colors.white.withOpacity(0.08)),
),
child: Text(
'No one here yet. Add at least ${AppStorage.minCircleMembersToUnlock} real app users to unlock your daily call.',
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
),
),
),
),
),
],
);
}
}

class _FrontCameraBackground extends StatelessWidget {
const _FrontCameraBackground({
required this.controller,
});

final CameraController controller;

@override
Widget build(BuildContext context) {
if (!controller.value.isInitialized || controller.value.previewSize == null) {
return Container(color: Colors.black);
}

final previewSize = controller.value.previewSize!;

return ClipRect(
child: OverflowBox(
alignment: Alignment.center,
maxWidth: double.infinity,
maxHeight: double.infinity,
child: FittedBox(
fit: BoxFit.cover,
child: SizedBox(
width: previewSize.height,
height: previewSize.width,
child: CameraPreview(controller),
),
),
),
);
}
}