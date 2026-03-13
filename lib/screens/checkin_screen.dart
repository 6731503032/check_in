// lib/screens/checkin_screen.dart
// Steps: 0=Identity  1=Selfie  2=GPS  3=QR  4=Reflection

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/attendance_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  int _step = 0;
  static const _primaryColor = Color(0xFF1565C0);
  static const _requiredDomain = 'lamduan.mfu.ac.th';
  final _stepLabels = ['Identity', 'Selfie', 'GPS', 'QR', 'Reflect'];

  // Step 0 – identity
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _studentName;
  String? _studentEmail;
  bool _googleSignedIn = false;

  // Step 1 – selfie
  XFile? _facePhoto;

  // Step 2 – GPS
  double? _latitude;
  double? _longitude;

  // Step 3 – QR
  String? _qrData;
  MobileScannerController? _scannerCtrl;

  // Step 4 – reflection
  final _prevTopicCtrl = TextEditingController();
  final _expTopicCtrl = TextEditingController();
  int _mood = 3;

  bool _isLoading = false;
  // Prevents the same error from showing multiple times rapidly
  bool _errorShowing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _prevTopicCtrl.dispose();
    _expTopicCtrl.dispose();
    _scannerCtrl?.dispose();
    super.dispose();
  }

  // ── Back one step ───────────────────────────────────────────────────────
  void _goBack() {
    if (_step > 0) {
      if (_step == 3) {
        _scannerCtrl?.stop();
        _scannerCtrl?.dispose();
        _scannerCtrl = null;
      }
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  // ── Error with debounce (Fix #2) ────────────────────────────────────────
  void _showError(String msg) {
    if (_errorShowing) return;
    _errorShowing = true;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ))
        .closed
        .then((_) => _errorShowing = false);
  }

  // ═══ STEP 0 — Google Sign-In ════════════════════════════════════════════
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.signInWithGoogle();
      setState(() {
        _studentName = user.displayName ?? user.email!.split('@').first;
        _studentEmail = user.email!;
        _googleSignedIn = true;
        _step = 1;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _submitIdentity() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    if (name.isEmpty) { _showError('Please enter your name or student ID.'); return; }
    if (!email.endsWith('@$_requiredDomain')) {
      _showError('Email must end with @$_requiredDomain'); return;
    }
    setState(() { _studentName = name; _studentEmail = email; _step = 1; });
  }

  // ═══ STEP 1 — Selfie (Fix #3: works on both web and mobile) ════════════
  Future<void> _takeSelfie() async {
    setState(() => _isLoading = true);
    try {
      if (!kIsWeb) {
        // Mobile: request camera permission first
        final status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          _showError('Camera permission is required for the selfie.');
          return;
        }
      }

      final picker = ImagePicker();
      // On web: opens file picker (or camera on mobile Chrome)
      // On mobile: opens front camera
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 600,
      );
      if (photo != null) setState(() { _facePhoto = photo; });
    } catch (e) {
      // On web, if camera source fails, fall back to gallery/file picker
      if (kIsWeb) {
        try {
          final picker = ImagePicker();
          final photo = await picker.pickImage(source: ImageSource.gallery);
          if (photo != null) setState(() { _facePhoto = photo; });
        } catch (e2) {
          _showError('Could not access camera or file picker: $e2');
        }
      } else {
        _showError('Could not open camera: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ═══ STEP 2 — GPS ═══════════════════════════════════════════════════════
  Future<void> _getLocation() async {
    setState(() => _isLoading = true);
    try {
      if (!kIsWeb) {
        final status = await Permission.locationWhenInUse.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          _showError('Location permission is required.'); return;
        }
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _showError('Location denied permanently. Enable in settings.'); return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() { _latitude = pos.latitude; _longitude = pos.longitude; _step = 3; });
    } catch (e) {
      _showError('Could not get location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ═══ STEP 3 — QR (Fix #4: works on web too via browser camera) ══════════
  void _initScanner() {
    _scannerCtrl ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  void _onQRScanned(String data) {
    _scannerCtrl?.stop();
    setState(() { _qrData = data; _step = 4; });
  }

  // ═══ STEP 4 — Submit ════════════════════════════════════════════════════
  Future<void> _submitForm() async {
    if (_prevTopicCtrl.text.isEmpty || _expTopicCtrl.text.isEmpty) {
      _showError('Please fill in all fields.'); return;
    }
    setState(() => _isLoading = true);
    try {
      final record = AttendanceRecord(
        id: const Uuid().v4(),
        studentId: _studentName!,
        studentEmail: _studentEmail!,
        checkInTime: DateTime.now(),
        latitude: _latitude!,
        longitude: _longitude!,
        qrData: _qrData!,
        previousTopic: _prevTopicCtrl.text.trim(),
        expectedTopic: _expTopicCtrl.text.trim(),
        moodBefore: _mood,
        facePhotoPath: _facePhoto?.path,
      );
      await StorageService.insertRecord(record);
      await FirebaseService.saveRecord(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Checked in successfully!'),
          backgroundColor: Color(0xFF2E7D32),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════ BUILD ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: _step == 0 ? 'Back to Home' : 'Back to ${_stepLabels[_step - 1]}',
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _goBack,
          ),
          title: const Text('Check-in to Class',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildProgressBar(),
            if (_step > 0)
              Container(
                color: _primaryColor.withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: _goBack,
                    child: Row(children: [
                      const Icon(Icons.arrow_back_ios_rounded,
                          size: 12, color: _primaryColor),
                      const SizedBox(width: 4),
                      Text('Back to ${_stepLabels[_step - 1]}',
                          style: const TextStyle(
                              fontSize: 12, color: _primaryColor,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  const Spacer(),
                  Text('Step ${_step + 1} of ${_stepLabels.length}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Progress bar ─────────────────────────────────────────────────────────
  Widget _buildProgressBar() => Container(
    color: _primaryColor,
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
    child: Row(
      children: List.generate(_stepLabels.length, (i) {
        final isActive = _step == i;
        final isDone = _step > i;
        return Expanded(
          child: Row(children: [
            if (i > 0)
              Expanded(child: Container(
                  height: 2, color: isDone ? Colors.white : Colors.white30)),
            GestureDetector(
              onTap: isDone ? () => setState(() => _step = i) : null,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: isDone || isActive ? Colors.white : Colors.white30,
                  child: Text(isDone ? '✓' : '${i + 1}',
                      style: TextStyle(
                        color: isDone || isActive ? _primaryColor : Colors.white,
                        fontSize: 10, fontWeight: FontWeight.bold,
                      )),
                ),
                const SizedBox(height: 3),
                Text(_stepLabels[i],
                    style: TextStyle(
                      fontSize: 8,
                      color: isActive ? Colors.white
                          : (isDone ? Colors.white70 : Colors.white38),
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    )),
              ]),
            ),
          ]),
        );
      }),
    ),
  );

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0: return _buildIdentityStep();
      case 1: return _buildSelfieStep();
      case 2: return _buildGPSStep();
      case 3: return _buildQRStep();
      case 4: return _buildFormStep();
      default: return const SizedBox();
    }
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
        color: _primaryColor.withValues(alpha: 0.08),
        blurRadius: 12, offset: const Offset(0, 4),
      )],
    ),
    child: child,
  );

  // ─── STEP 0: Identity ────────────────────────────────────────────────────
  Widget _buildIdentityStep() => _card(Column(
    children: [
      const Text('👤', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      const Text('Identify Yourself',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('Use your @$_requiredDomain email',
          style: const TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 24),

      // Google Sign-In button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _signInWithGoogle,
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Image.network(
                  'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                  width: 20, height: 20,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.login, size: 20, color: Colors.red),
                ),
          label: Text(_isLoading ? 'Signing in...' : 'Sign in with Google',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.grey),
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      const SizedBox(height: 16),
      const Row(children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('or enter manually',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        Expanded(child: Divider()),
      ]),
      const SizedBox(height: 16),

      _textField(ctrl: _nameCtrl, label: 'Full Name / Student ID',
          hint: 'e.g. John Doe', icon: Icons.person_outline),
      const SizedBox(height: 12),
      _textField(ctrl: _emailCtrl, label: 'University Email',
          hint: '65012345@lamduan.mfu.ac.th',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 20),
      _primaryBtn(label: 'Continue', icon: Icons.arrow_forward_rounded,
          onTap: _submitIdentity),
    ],
  ));

  // ─── STEP 1: Selfie ──────────────────────────────────────────────────────
  Widget _buildSelfieStep() => _card(Column(
    children: [
      const Text('🤳', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      const Text('Take a Selfie',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(
        kIsWeb
            ? 'Upload a photo or use your webcam below.'
            : 'Your face confirms you are the one checking in.',
        style: const TextStyle(color: Colors.grey, fontSize: 13),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),

      // Photo preview or placeholder
      if (_facePhoto != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(80),
          child: kIsWeb
              ? Image.network(_facePhoto!.path,
                  width: 160, height: 160, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 160, height: 160,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.person, size: 60, color: Colors.grey),
                  ))
              : Image.file(File(_facePhoto!.path),
                  width: 160, height: 160, fit: BoxFit.cover),
        ),
        const SizedBox(height: 12),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
          SizedBox(width: 6),
          Text('Photo captured!',
              style: TextStyle(color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _outlineBtn(
              label: 'Retake', icon: Icons.refresh_rounded,
              onTap: _takeSelfie)),
          const SizedBox(width: 12),
          Expanded(child: _primaryBtn(
              label: 'Continue', icon: Icons.arrow_forward_rounded,
              onTap: () => setState(() => _step = 2))),
        ]),
      ] else ...[
        Container(
          width: 160, height: 160,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: const Icon(Icons.person, size: 70, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        _primaryBtn(
          label: _isLoading
              ? 'Opening camera...'
              : (kIsWeb ? '📷 Take Photo / Upload' : 'Open Front Camera'),
          icon: Icons.camera_alt_rounded,
          loading: _isLoading,
          onTap: _isLoading ? null : _takeSelfie,
        ),
        const SizedBox(height: 10),
        // Allow skipping selfie
        TextButton(
          onPressed: () => setState(() => _step = 2),
          child: const Text('Skip for now',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      ],
    ],
  ));

  // ─── STEP 2: GPS ─────────────────────────────────────────────────────────
  Widget _buildGPSStep() => _card(Column(
    children: [
      const Text('📍', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      const Text('Get Your Location',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Confirms you are physically in the classroom.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      if (_latitude != null) ...[
        _successBadge(
            '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'),
        const SizedBox(height: 16),
      ],
      _primaryBtn(
        label: _isLoading ? 'Locating...' : 'Get GPS Location',
        icon: Icons.my_location_rounded,
        loading: _isLoading,
        onTap: _isLoading ? null : _getLocation,
      ),
    ],
  ));

  // ─── STEP 3: QR ──────────────────────────────────────────────────────────
  Widget _buildQRStep() {
    // Init scanner lazily when this step is shown
    _initScanner();
    return _card(Column(
      children: [
        const Text('📷', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text('Scan Class QR Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Allow camera access when prompted, then point at the QR code.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Scanner — MobileScanner handles camera permission natively on web too
        Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primaryColor, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: _scannerCtrl,
              onDetect: (capture) {
                final b = capture.barcodes.firstOrNull;
                if (b?.rawValue != null) _onQRScanned(b!.rawValue!);
              },
              errorBuilder: (context, error, child) => Container(
                color: Colors.grey.shade100,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Camera not available',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(error.errorDetails?.message ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Scanning indicator
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
                color: Colors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text('Camera active — scanning for QR code...',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _showManualQR,
          icon: const Icon(Icons.keyboard_alt_outlined, size: 16),
          label: const Text('Enter code manually instead'),
        ),
      ],
    ));
  }

  void _showManualQR() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Class Code'),
        content: TextField(controller: c,
            decoration: const InputDecoration(
                hintText: 'e.g. CS101-2025',
                border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (c.text.isNotEmpty) {
                Navigator.pop(context);
                _onQRScanned(c.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ─── STEP 4: Reflection ──────────────────────────────────────────────────
  Widget _buildFormStep() => _card(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Center(child: Text('📝', style: TextStyle(fontSize: 52))),
      const SizedBox(height: 12),
      const Center(child: Text('Pre-class Reflection',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      const SizedBox(height: 4),
      const Center(child: Text('Almost done — tell us about today.',
          style: TextStyle(color: Colors.grey, fontSize: 13))),
      const SizedBox(height: 20),

      // Identity badge
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          _photoAvatar(),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_studentName ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(_studentEmail ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
          Icon(_googleSignedIn ? Icons.verified : Icons.verified_user,
              color: _primaryColor, size: 18),
        ]),
      ),
      const SizedBox(height: 16),

      _textField(ctrl: _prevTopicCtrl,
          label: 'What was covered last class?',
          hint: 'e.g. Introduction to Flutter widgets',
          icon: Icons.history_edu_outlined, maxLines: 2),
      const SizedBox(height: 14),
      _textField(ctrl: _expTopicCtrl,
          label: 'What do you expect to learn today?',
          hint: 'e.g. State management with Provider',
          icon: Icons.lightbulb_outline, maxLines: 2),
      const SizedBox(height: 20),

      const Text('How are you feeling before class?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 10),
      _moodSelector(_mood, (v) => setState(() => _mood = v)),
      const SizedBox(height: 20),

      Wrap(spacing: 8, runSpacing: 6, children: [
        _infoBadge(Icons.qr_code, _qrData ?? ''),
        _infoBadge(Icons.location_on,
            '${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}'),
      ]),
      const SizedBox(height: 20),

      _primaryBtn(label: 'Submit Check-in', icon: Icons.check_rounded,
          loading: _isLoading, onTap: _isLoading ? null : _submitForm),
    ],
  ));

  // ── Photo avatar helper ──────────────────────────────────────────────────
  Widget _photoAvatar() {
    if (_facePhoto == null) {
      return const CircleAvatar(radius: 20,
          backgroundColor: Color(0xFF1565C0),
          child: Icon(Icons.person, color: Colors.white, size: 22));
    }
    if (kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(_facePhoto!.path,
            width: 40, height: 40, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const CircleAvatar(radius: 20,
                child: Icon(Icons.person))),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.file(File(_facePhoto!.path),
          width: 40, height: 40, fit: BoxFit.cover),
    );
  }

  // ── Shared widgets ───────────────────────────────────────────────────────
  Widget _moodSelector(int current, void Function(int) onSelect) {
    final moods = [
      {'s': 1, 'e': '😡', 'l': 'Very\nNeg'},
      {'s': 2, 'e': '🙁', 'l': 'Negative'},
      {'s': 3, 'e': '😐', 'l': 'Neutral'},
      {'s': 4, 'e': '🙂', 'l': 'Positive'},
      {'s': 5, 'e': '😄', 'l': 'Very\nPos'},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: moods.map((m) {
        final score = m['s'] as int;
        final sel = current == score;
        return GestureDetector(
          onTap: () => onSelect(score),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? _primaryColor : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? _primaryColor : Colors.grey.shade300),
            ),
            child: Column(children: [
              Text(m['e'] as String, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(m['l'] as String,
                  style: TextStyle(fontSize: 9,
                      color: sel ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _textField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: true, fillColor: const Color(0xFFF8FAFF),
        ),
      ),
    ],
  );

  Widget _primaryBtn({
    required String label,
    IconData? icon,
    bool loading = false,
    VoidCallback? onTap,
  }) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: loading
          ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Icon(icon ?? Icons.check, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _outlineBtn({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      side: const BorderSide(color: _primaryColor),
      foregroundColor: _primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _successBadge(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(
          fontSize: 12, color: Color(0xFF2E7D32))),
    ]),
  );

  Widget _infoBadge(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: _primaryColor),
      const SizedBox(width: 4),
      Text(text,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          overflow: TextOverflow.ellipsis),
    ]),
  );
}