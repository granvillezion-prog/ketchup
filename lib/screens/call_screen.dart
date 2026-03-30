import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CallScreen extends StatefulWidget {
final String hiddenName;
final String phone;
final VoidCallback onConnect;
final VoidCallback onComplete;

const CallScreen({
super.key,
required this.hiddenName,
required this.phone,
required this.onConnect,
required this.onComplete,
});

@override
State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
with WidgetsBindingObserver {
static const int _baseSeconds = 300;
static const int _extendSeconds = 300;

static const Color _brandPurple = Color(0xFFB75AFF);
static const Color _brandPurpleDim = Color(0xFF7A4BAE);
static const Color _faceTimeDark = Color(0xFF2C2C2E);
static const Color _endRed = Color(0xFFFF5A52);

static const double _previewWidth = 112;
static const double _previewHeight = 150;

CameraController? _cameraController;
bool _cameraReady = false;
bool _cameraInitializing = false;
CameraLensDirection _currentLens = CameraLensDirection.front;

Timer? _timer;
Timer? _devConnectTimer;

int _remaining = _baseSeconds;
bool _extended = false;
bool _connected = false;
bool _speakerOn = true;
bool _muted = false;
bool _showCameraPreviewSmall = true;
bool _ending = false;

Offset? _previewOffset;

@override
void initState() {
super.initState();
WidgetsBinding.instance.addObserver(this);
_initCamera();
_startCallImmediately();
}

@override
void dispose() {
WidgetsBinding.instance.removeObserver(this);
_timer?.cancel();
_devConnectTimer?.cancel();
_cameraController?.dispose();
super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
final cam = _cameraController;
if (cam == null) return;

if (state == AppLifecycleState.inactive ||
state == AppLifecycleState.paused ||
state == AppLifecycleState.detached) {
cam.dispose();
_cameraController = null;
if (mounted) {
setState(() => _cameraReady = false);
}
} else if (state == AppLifecycleState.resumed) {
_initCamera(lensDirection: _currentLens);
}
}

Future<void> _initCamera({
CameraLensDirection? lensDirection,
}) async {
if (_cameraInitializing) return;
_cameraInitializing = true;

try {
final cameras = await availableCameras();
if (!mounted) return;

final targetLens = lensDirection ?? _currentLens;
CameraDescription? chosen;

for (final cam in cameras) {
if (cam.lensDirection == targetLens) {
chosen = cam;
break;
}
}

chosen ??= cameras.isNotEmpty ? cameras.first : null;
if (chosen == null) {
if (mounted) {
setState(() => _cameraReady = false);
}
return;
}

final controller = CameraController(
chosen,
ResolutionPreset.high,
enableAudio: false,
);

await controller.initialize();

if (!mounted) {
await controller.dispose();
return;
}

await _cameraController?.dispose();

setState(() {
_cameraController = controller;
_cameraReady = true;
_currentLens = chosen!.lensDirection;
});
} catch (_) {
if (!mounted) return;
setState(() => _cameraReady = false);
} finally {
_cameraInitializing = false;
}
}

void _startCallImmediately() {
widget.onConnect();

setState(() {
_remaining = _baseSeconds;
_extended = false;
_connected = false;
});

_timer?.cancel();
_timer = Timer.periodic(const Duration(seconds: 1), (_) {
if (!mounted) return;

if (_remaining <= 1) {
_endCall();
return;
}

setState(() {
_remaining -= 1;
});
});

_devConnectTimer?.cancel();
_devConnectTimer = Timer(const Duration(milliseconds: 1200), () {
if (!mounted) return;
setState(() {
_connected = true;
});
});
}

Future<void> _flipCamera() async {
final nextLens = _currentLens == CameraLensDirection.front
? CameraLensDirection.back
: CameraLensDirection.front;
await _initCamera(lensDirection: nextLens);
}

void _toggleSpeaker() {
setState(() => _speakerOn = !_speakerOn);
}

void _toggleMute() {
setState(() => _muted = !_muted);
}

void _togglePreviewSize() {
setState(() => _showCameraPreviewSmall = !_showCameraPreviewSmall);
}

void _extendCall() {
if (_extended) return;

setState(() {
_remaining += _extendSeconds;
_extended = true;
});
}

void _endCall() {
if (_ending) return;
_ending = true;

_timer?.cancel();
_devConnectTimer?.cancel();

widget.onComplete();

if (mounted) {
Navigator.of(context).pop();
}
}

String _formatTime(int seconds) {
final m = (seconds ~/ 60).toString().padLeft(2, '0');
final s = (seconds % 60).toString().padLeft(2, '0');
return '$m:$s';
}

Widget _buildFullCamera() {
final controller = _cameraController;

if (!_cameraReady || controller == null || !controller.value.isInitialized) {
return Container(
color: Colors.black,
alignment: Alignment.center,
child: const Icon(
Icons.videocam_off_rounded,
color: Colors.white38,
size: 52,
),
);
}

final size = controller.value.previewSize;
if (size == null) {
return Container(color: Colors.black);
}

return ClipRect(
child: OverflowBox(
alignment: Alignment.center,
maxWidth: double.infinity,
maxHeight: double.infinity,
child: FittedBox(
fit: BoxFit.cover,
child: SizedBox(
width: size.height,
height: size.width,
child: CameraPreview(controller),
),
),
),
);
}

Widget _buildSmallPreview() {
return GestureDetector(
onTap: _togglePreviewSize,
child: Container(
width: _previewWidth,
height: _previewHeight,
decoration: BoxDecoration(
color: Colors.black,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: Colors.white.withOpacity(0.18),
width: 1,
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.35),
blurRadius: 16,
offset: const Offset(0, 8),
),
],
),
clipBehavior: Clip.antiAlias,
child: Stack(
fit: StackFit.expand,
children: [
_buildFullCamera(),
Positioned(
right: 8,
bottom: 8,
child: Container(
width: 28,
height: 28,
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.6),
shape: BoxShape.circle,
),
child: const Icon(
Icons.cameraswitch_rounded,
color: Colors.white,
size: 18,
),
),
),
],
),
),
);
}

Widget _buildRemoteBackground() {
return Stack(
fit: StackFit.expand,
children: [
Container(color: Colors.black),
Positioned.fill(
child: DecoratedBox(
decoration: const BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Color(0xFF16121F),
Color(0xFF120714),
Colors.black,
],
),
),
),
),
],
);
}

Widget _buildTimer() {
return Positioned.fill(
child: IgnorePointer(
child: Center(
child: Text(
_formatTime(_remaining),
style: const TextStyle(
color: _brandPurple,
fontSize: 34,
fontWeight: FontWeight.w900,
letterSpacing: 0.8,
height: 1,
shadows: [
Shadow(
color: Color(0x99B75AFF),
blurRadius: 18,
),
Shadow(
color: Color(0x66000000),
blurRadius: 8,
),
],
),
),
),
),
);
}

Widget _controlButton({
required Widget icon,
required String label,
required VoidCallback onTap,
Color fill = Colors.white,
}) {
return GestureDetector(
onTap: onTap,
child: SizedBox(
width: 66,
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 58,
height: 58,
decoration: BoxDecoration(
color: fill,
shape: BoxShape.circle,
),
child: Center(child: icon),
),
const SizedBox(height: 7),
Text(
label,
textAlign: TextAlign.center,
style: const TextStyle(
color: Colors.white,
fontSize: 12,
fontWeight: FontWeight.w500,
shadows: [
Shadow(
color: Colors.black87,
blurRadius: 6,
),
],
),
),
],
),
),
);
}

Widget _buildTopControls() {
return Positioned(
top: 112,
left: 0,
right: 0,
child: SafeArea(
bottom: false,
child: Padding(
padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceEvenly,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_controlButton(
icon: Icon(
_speakerOn
? Icons.volume_up_rounded
: Icons.volume_off_rounded,
color: Colors.black,
size: 29,
),
label: 'Speaker',
onTap: _toggleSpeaker,
),
_controlButton(
icon: const Icon(
Icons.videocam_rounded,
color: Colors.black,
size: 29,
),
label: 'Camera',
onTap: _flipCamera,
),
_controlButton(
icon: const Text(
'5',
style: TextStyle(
color: Colors.white,
fontSize: 28,
fontWeight: FontWeight.w900,
height: 1,
),
),
label: _extended ? 'Extended' : '+ 5',
onTap: _extendCall,
fill: _extended ? _brandPurpleDim : _brandPurple,
),
_controlButton(
icon: Icon(
_muted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
color: _muted ? Colors.redAccent : Colors.white,
size: 28,
),
label: 'Mute',
onTap: _toggleMute,
fill: _faceTimeDark,
),
_controlButton(
icon: const Icon(
Icons.close_rounded,
color: Colors.white,
size: 30,
),
label: 'End',
onTap: _endCall,
fill: _endRed,
),
],
),
),
),
);
}

Offset _defaultPreviewOffset(Size size, EdgeInsets padding) {
return Offset(
size.width - _previewWidth - 20,
padding.top + 22,
);
}

Offset _clampPreviewOffset(
Offset offset,
Size size,
EdgeInsets padding,
) {
final minX = 12.0;
final maxX = size.width - _previewWidth - 12.0;
final minY = padding.top + 10.0;
final maxY = size.height - _previewHeight - padding.bottom - 12.0;

return Offset(
offset.dx.clamp(minX, maxX),
offset.dy.clamp(minY, maxY),
);
}

Widget _buildDraggablePreview(BoxConstraints constraints) {
final padding = MediaQuery.of(context).padding;
final size = Size(constraints.maxWidth, constraints.maxHeight);

_previewOffset ??= _defaultPreviewOffset(size, padding);
_previewOffset = _clampPreviewOffset(_previewOffset!, size, padding);

return Positioned(
left: _previewOffset!.dx,
top: _previewOffset!.dy,
child: GestureDetector(
onPanUpdate: (details) {
setState(() {
_previewOffset = _clampPreviewOffset(
_previewOffset! + details.delta,
size,
padding,
);
});
},
child: _buildSmallPreview(),
),
);
}

@override
Widget build(BuildContext context) {
final showSmallPreview = _connected && _showCameraPreviewSmall;

return Scaffold(
backgroundColor: Colors.black,
body: LayoutBuilder(
builder: (context, constraints) {
return Stack(
fit: StackFit.expand,
children: [
if (_connected) _buildRemoteBackground() else _buildFullCamera(),
Positioned.fill(
child: DecoratedBox(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.black.withOpacity(0.18),
Colors.transparent,
Colors.black.withOpacity(0.10),
],
),
),
),
),
_buildTopControls(),
_buildTimer(),
if (showSmallPreview) _buildDraggablePreview(constraints),
if (!_connected)
Positioned(
left: 0,
right: 0,
bottom: 148,
child: Center(
child: ClipRRect(
borderRadius: BorderRadius.circular(18),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 10,
),
color: Colors.white.withOpacity(0.12),
child: const Text(
'Calling...',
style: TextStyle(
color: Colors.white,
fontSize: 15,
fontWeight: FontWeight.w700,
),
),
),
),
),
),
),
],
);
},
),
);
}
}