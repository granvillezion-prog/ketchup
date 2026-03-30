import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_router.dart';
import '../services/firestore_service.dart';
import '../services/friends_graph_service.dart';
import '../storage.dart';

class ProfileHubScreen extends StatefulWidget {
const ProfileHubScreen({
super.key,
this.friendName,
});

final String? friendName;

@override
State<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends State<ProfileHubScreen> {
final _picker = ImagePicker();

File? _pickedPhoto;
bool _uploadingPhoto = false;
int? _realFriendsCount;
bool _loadingRealFriendsCount = false;

bool get _isFriendView {
final t = widget.friendName?.trim() ?? '';
return t.isNotEmpty;
}

@override
void initState() {
super.initState();
if (!_isFriendView) {
_loadRealFriendsCount();
}
}

Future<void> _loadRealFriendsCount() async {
setState(() => _loadingRealFriendsCount = true);
try {
final count = await FriendsGraphService.getMyOnAppFriendCount();
if (!mounted) return;
setState(() {
_realFriendsCount = count;
_loadingRealFriendsCount = false;
});
} catch (_) {
if (!mounted) return;
setState(() {
_realFriendsCount = 0;
_loadingRealFriendsCount = false;
});
}
}

String _firstNameOnly(String full) {
final t = full.trim();
if (t.isEmpty) return '';
final parts =
t.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
return parts.isEmpty ? t : parts.first;
}

Future<void> _openIconPickerSelf() async {
if (_isFriendView) return;

await Navigator.pushNamed(
context,
AppRouter.iconPicker,
arguments: {'mode': 'self'},
);
if (!mounted) return;
setState(() {});
}

Future<void> _openProfilePicMenu() async {
if (_isFriendView) return;

showModalBottomSheet(
context: context,
builder: (_) => SafeArea(
child: Wrap(
children: [
ListTile(
leading: const Icon(Icons.photo_library_rounded),
title: const Text('Choose photo'),
onTap: () {
Navigator.pop(context);
_pickAndSetProfilePhoto(ImageSource.gallery);
},
),
ListTile(
leading: const Icon(Icons.photo_camera_rounded),
title: const Text('Take photo'),
onTap: () {
Navigator.pop(context);
_pickAndSetProfilePhoto(ImageSource.camera);
},
),
ListTile(
leading: const Icon(Icons.emoji_emotions_rounded),
title: const Text('Choose icon'),
onTap: () {
Navigator.pop(context);
_openIconPickerSelf();
},
),
],
),
),
);
}

Future<void> _pickAndSetProfilePhoto(ImageSource source) async {
final xfile = await _picker.pickImage(
source: source,
imageQuality: 80,
maxWidth: 900,
);
if (xfile == null) return;

final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
if (uid.isEmpty) return;

setState(() {
_pickedPhoto = File(xfile.path);
_uploadingPhoto = true;
});

try {
final url = await _uploadProfilePhoto(uid, _pickedPhoto!);

final fs = FirestoreService(uid);
await fs.updateProfilePhoto(photoUrl: url);

await AppStorage.setProfilePhotoUrl(url);
await AppStorage.setProfileIconId('');

if (!mounted) return;
setState(() {
_uploadingPhoto = false;
});
} catch (e) {
if (!mounted) return;
setState(() => _uploadingPhoto = false);
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Photo upload failed: $e')),
);
}
}

Future<String> _uploadProfilePhoto(String uid, File file) async {
final ref = FirebaseStorage.instance.ref().child('profilePhotos/$uid.jpg');
await ref.putFile(file);
return await ref.getDownloadURL();
}

@override
Widget build(BuildContext context) {
final isFriendView = _isFriendView;

final fullName = isFriendView
? (widget.friendName ?? '').trim()
: AppStorage.getProfileName().trim();
final firstName = _firstNameOnly(fullName);

final username = isFriendView ? '' : AppStorage.getProfileUsername().trim();
final photoUrl = isFriendView ? '' : AppStorage.getProfilePhotoUrl().trim();

final iconId = isFriendView
? AppStorage.getFriendIconId(fullName).trim()
: AppStorage.getProfileIconId().trim();
final iconAsset = iconId.isEmpty ? '' : 'assets/icons/$iconId.png';

final fallbackInitial = (firstName.isNotEmpty
? firstName[0]
: (fullName.isNotEmpty ? fullName[0] : 'Z'))
.toUpperCase();

Widget buildProfileInner() {
if (!isFriendView && _pickedPhoto != null) {
return Image.file(
_pickedPhoto!,
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
);
}

if (!isFriendView && photoUrl.isNotEmpty) {
return Image.network(
photoUrl,
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (_, __, ___) =>
_InitialIcon(initial: fallbackInitial),
);
}

if (iconAsset.isNotEmpty) {
return Image.asset(
iconAsset,
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (_, __, ___) =>
_InitialIcon(initial: fallbackInitial),
);
}

return _InitialIcon(initial: fallbackInitial);
}

Widget profileIconBox() {
return ClipRRect(
borderRadius: BorderRadius.circular(28),
child: Stack(
children: [
Positioned.fill(child: buildProfileInner()),
Positioned.fill(
child: DecoratedBox(
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.02),
),
),
),
],
),
);
}

final friendsLine = isFriendView
? 'In your circle'
: _loadingRealFriendsCount
? 'Loading real friends...'
: '${_realFriendsCount ?? 0} real friends';

return Scaffold(
backgroundColor: Colors.black,
extendBodyBehindAppBar: true,
body: Container(
decoration: const BoxDecoration(
image: DecorationImage(
image: AssetImage('assets/today_screen2.jpg'),
fit: BoxFit.cover,
),
),
child: SafeArea(
top: false,
child: Padding(
padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const SizedBox(height: 8),
Row(
children: [
if (isFriendView)
IconButton(
onPressed: () => Navigator.pop(context),
icon: const Icon(
Icons.arrow_back_rounded,
color: Colors.white,
size: 28,
),
)
else
IconButton(
onPressed: () =>
Navigator.pushNamed(context, AppRouter.circle),
icon: const Icon(
Icons.group_add_rounded,
color: Colors.white,
size: 28,
),
),
const Spacer(),
if (!isFriendView) ...[
IconButton(
onPressed: () {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Calendar (coming soon)'),
),
);
},
icon: const Icon(
Icons.calendar_month_rounded,
color: Colors.white,
size: 26,
),
),
IconButton(
onPressed: () =>
Navigator.pushNamed(context, AppRouter.settings),
icon: const Icon(
Icons.settings_rounded,
color: Colors.white,
size: 26,
),
),
],
],
),
const SizedBox(height: 16),
Expanded(
child: Column(
children: [
const SizedBox(height: 10),
GestureDetector(
onTap: isFriendView ? null : _openProfilePicMenu,
child: Stack(
children: [
Container(
width: 170,
height: 170,
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.06),
borderRadius: BorderRadius.circular(28),
border: Border.all(
color: Colors.white.withOpacity(0.10),
width: 1,
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.45),
blurRadius: 36,
spreadRadius: 4,
),
],
),
child: profileIconBox(),
),
if (!isFriendView && _uploadingPhoto)
Positioned.fill(
child: Container(
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.35),
borderRadius: BorderRadius.circular(28),
),
child: const Center(
child: CircularProgressIndicator(),
),
),
),
],
),
),
const SizedBox(height: 22),
Align(
alignment: Alignment.centerLeft,
child: Text(
firstName.isEmpty ? 'You' : firstName,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
fontSize: 34,
height: 1.0,
),
),
),
const SizedBox(height: 6),
if (!isFriendView)
Align(
alignment: Alignment.centerLeft,
child: Row(
children: [
Text(
username.isEmpty ? '@username' : '@$username',
style: TextStyle(
color: Colors.white.withOpacity(0.85),
fontWeight: FontWeight.w900,
fontSize: 18,
),
),
const SizedBox(width: 10),
Icon(
Icons.lock_rounded,
size: 18,
color: Colors.white.withOpacity(0.85),
),
],
),
)
else
Align(
alignment: Alignment.centerLeft,
child: Text(
'Friend on Know No Know',
style: TextStyle(
color: Colors.white.withOpacity(0.85),
fontWeight: FontWeight.w800,
fontSize: 18,
),
),
),
const SizedBox(height: 18),
Align(
alignment: Alignment.centerLeft,
child: Text(
friendsLine,
style: TextStyle(
color: Colors.white.withOpacity(0.72),
fontWeight: FontWeight.w800,
fontSize: 16,
),
),
),
const SizedBox(height: 8),
if (!isFriendView)
Align(
alignment: Alignment.centerLeft,
child: Text(
'Only real app users count toward your daily call network.',
style: TextStyle(
color: Colors.white.withOpacity(0.56),
fontWeight: FontWeight.w700,
fontSize: 12,
),
),
),
const SizedBox(height: 18),
if (!isFriendView)
Row(
children: [
Expanded(
child: Container(
height: 54,
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.12),
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: Colors.white.withOpacity(0.10),
width: 1,
),
),
child: InkWell(
borderRadius: BorderRadius.circular(18),
onTap: () {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Share Profile (coming soon)',
),
),
);
},
child: const Center(
child: Text(
'Share Profile',
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
fontSize: 16,
),
),
),
),
),
),
const SizedBox(width: 10),
Container(
height: 54,
width: 54,
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.12),
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: Colors.white.withOpacity(0.10),
width: 1,
),
),
child: IconButton(
icon: const Icon(
Icons.edit_rounded,
color: Colors.white,
),
onPressed: () {
Navigator.pushNamed(
context,
AppRouter.profile,
);
},
),
),
],
)
else
Container(
width: double.infinity,
height: 54,
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.12),
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: Colors.white.withOpacity(0.10),
width: 1,
),
),
child: InkWell(
borderRadius: BorderRadius.circular(18),
onTap: () => Navigator.pop(context),
child: const Center(
child: Text(
'Back',
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
fontSize: 16,
),
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
);
}
}

class _InitialIcon extends StatelessWidget {
const _InitialIcon({required this.initial});
final String initial;

@override
Widget build(BuildContext context) {
return Container(
alignment: Alignment.center,
color: Colors.black.withOpacity(0.10),
child: Text(
initial,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
fontSize: 48,
),
),
);
}
}