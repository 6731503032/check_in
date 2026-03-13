// lib/screens/checkin_screen.dart
// Steps: 0=Identity  1=Selfie  2=GPS  3=QR  4=Reflection

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/attendance_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';

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

  // ── Step 0 ────────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _studentName;
  String? _studentEmail;

  // ── Step 1 – live camera selfie ───────────────────────────────────────
  CameraController? _camCtrl;
  bool _camReady = false;
  bool _camError = false;
  String? _camErrorMsg;
  XFile? _capturedPhoto; // holds the taken photo

  // ── Step 2 ────────────────────────────────────────────────────────────
  double? _latitude;
  double? _longitude;

  // ── Step 3 ────────────────────────────────────────────────────────────
  String? _qrData;
  MobileScannerController? _scannerCtrl;

  // ── Step 4 ────────────────────────────────────────────────────────────
  final _prevTopicCtrl = TextEditingController();
  final _expTopicCtrl = TextEditingController();
  int _mood = 3;

  bool _isLoading = false;
  bool _errorShowing = false;
  bool _submitting = false;

  // ─────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _prevTopicCtrl.dispose();
    _expTopicCtrl.dispose();
    _camCtrl?.dispose();
    _scannerCtrl?.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────
  void _goBack() {
    if (_step == 3) { _scannerCtrl?.stop(); _scannerCtrl?.dispose(); _scannerCtrl = null; }
    if (_step == 1) { _camCtrl?.dispose(); _camCtrl = null; _camReady = false; _capturedPhoto = null; }
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

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

  // ═══ STEP 0 — Identity ════════════════════════════════════════════════
  void _submitIdentity() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    if (name.isEmpty) { _showError('Please enter your name or student ID.'); return; }
    if (!email.endsWith('@$_requiredDomain')) {
      _showError('Email must end with @$_requiredDomain'); return;
    }
    setState(() { _studentName = name; _studentEmail = email; });
    _initSelfieCamera(); // pre-init camera as we move to step 1
    setState(() => _step = 1);
  }

  // ═══ STEP 1 — Live Camera Selfie ═════════════════════════════════════
  Future<void> _initSelfieCamera() async {
    setState(() { _camReady = false; _camError = false; _camErrorMsg = null; _capturedPhoto = null; });
    try {
      // Request permission first on mobile
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          setState(() { _camError = true; _camErrorMsg = 'Camera permission denied. Enable it in settings.'; });
          return;
        }
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() { _camError = true; _camErrorMsg = 'No camera found on this device.'; });
        return;
      }
      // Prefer front camera
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camCtrl?.dispose();
      _camCtrl = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
      await _camCtrl!.initialize();
      if (mounted) setState(() => _camReady = true);
    } catch (e) {
      if (mounted) setState(() { _camError = true; _camErrorMsg = 'Could not start camera: $e'; });
    }
  }

  Future<void> _captureSelfie() async {
    if (_camCtrl == null || !_camCtrl!.value.isInitialized) return;
    setState(() => _isLoading = true);
    try {
      final photo = await _camCtrl!.takePicture();
      await _camCtrl!.dispose();
      _camCtrl = null;
      setState(() { _capturedPhoto = photo; _camReady = false; });
    } catch (e) {
      _showError('Could not capture photo: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _retakeSelfie() async {
    setState(() { _capturedPhoto = null; });
    await _initSelfieCamera();
  }

  // ═══ STEP 2 — GPS ═════════════════════════════════════════════════════
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
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        _showError('Location denied permanently. Enable in settings.'); return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 15));
      setState(() { _latitude = pos.latitude; _longitude = pos.longitude; _step = 3; });
    } catch (e) {
      _showError('Could not get location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ═══ STEP 3 — QR ══════════════════════════════════════════════════════
  MobileScannerController _getScanner() {
    _scannerCtrl ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      autoStart: true,
    );
    return _scannerCtrl!;
  }

  void _onQRScanned(String data) {
    _scannerCtrl?.stop();
    setState(() { _qrData = data; _step = 4; });
  }

  // ═══ STEP 4 — Submit ══════════════════════════════════════════════════
  Future<void> _submitForm() async {
    if (_prevTopicCtrl.text.isEmpty || _expTopicCtrl.text.isEmpty) {
      _showError('Please fill in all fields.'); return;
    }
    setState(() => _submitting = true);
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
        facePhotoPath: _capturedPhoto?.path,
      );

      // Fix: on web skip sqflite (it hangs), go straight to Firebase
      // On mobile save locally first then sync
      if (!kIsWeb) {
        await StorageService.insertRecord(record)
            .timeout(const Duration(seconds: 8), onTimeout: () {
          debugPrint('Local DB timeout — continuing without local save');
        });
      }

      // Firebase sync — best-effort with timeout
      try {
        await FirebaseService.saveRecord(record)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Firebase sync failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Checked in successfully!'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to save check-in: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ═══════════════════ BUILD ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); },
      child: Stack(children: [
        Scaffold(
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
          body: Column(children: [
            _buildProgressBar(),
            if (_step > 0)
              Container(
                color: _primaryColor.withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: _goBack,
                    child: Row(children: [
                      const Icon(Icons.arrow_back_ios_rounded, size: 12, color: _primaryColor),
                      const SizedBox(width: 4),
                      Text('Back to ${_stepLabels[_step - 1]}',
                          style: const TextStyle(fontSize: 12, color: _primaryColor,
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
          ]),
        ),

        // Submit loading overlay
        if (_submitting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16))),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: Color(0xFF1565C0)),
                    SizedBox(height: 16),
                    Text('Saving check-in...',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    Text('Please wait',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────
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
              Expanded(child: Container(height: 2,
                  color: isDone ? Colors.white : Colors.white30)),
            GestureDetector(
              onTap: isDone ? () => setState(() => _step = i) : null,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: isDone || isActive ? Colors.white : Colors.white30,
                  child: Text(isDone ? '✓' : '${i + 1}',
                      style: TextStyle(
                          color: isDone || isActive ? _primaryColor : Colors.white,
                          fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 3),
                Text(_stepLabels[i], style: TextStyle(
                  fontSize: 8,
                  color: isActive ? Colors.white : (isDone ? Colors.white70 : Colors.white38),
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
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: _primaryColor.withValues(alpha: 0.08),
          blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: child,
  );

  // ─── STEP 0: Identity ─────────────────────────────────────────────────
  Widget _buildIdentityStep() => _card(Column(children: [
    const Text('👤', style: TextStyle(fontSize: 52)),
    const SizedBox(height: 12),
    const Text('Identify Yourself',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    Text('Use your @$_requiredDomain email',
        style: const TextStyle(color: Colors.grey, fontSize: 13)),
    const SizedBox(height: 28),

    _textField(ctrl: _nameCtrl, label: 'Full Name / Student ID',
        hint: 'e.g. John Doe or 6501234567', icon: Icons.person_outline),
    const SizedBox(height: 14),
    _textField(ctrl: _emailCtrl, label: 'University Email',
        hint: '6501234567@lamduan.mfu.ac.th', icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 24),
    _primaryBtn(label: 'Continue', icon: Icons.arrow_forward_rounded,
        onTap: _submitIdentity),
  ]));

  // ─── STEP 1: Selfie (live camera) ─────────────────────────────────────
  Widget _buildSelfieStep() {
    // Photo already taken — show preview
    if (_capturedPhoto != null) {
      return _card(Column(children: [
        const Text('🤳', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text('Selfie Captured!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: kIsWeb
              ? Image.network(_capturedPhoto!.path,
                  width: double.infinity, height: 280, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _photoPlaceholder())
              : Image.file(File(_capturedPhoto!.path),
                  width: double.infinity, height: 280, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
          SizedBox(width: 6),
          Text('Looks good!',
              style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _outlineBtn(label: 'Retake', icon: Icons.refresh_rounded,
              onTap: _retakeSelfie)),
          const SizedBox(width: 12),
          Expanded(child: _primaryBtn(label: 'Continue', icon: Icons.arrow_forward_rounded,
              onTap: () => setState(() => _step = 2))),
        ]),
      ]));
    }

    // Camera error state
    if (_camError) {
      return _card(Column(children: [
        const Text('📷', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text('Camera Unavailable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_camErrorMsg ?? 'Unknown error',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        _primaryBtn(label: 'Retry Camera', icon: Icons.refresh_rounded,
            onTap: _initSelfieCamera),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _step = 2),
          child: const Text('Skip for now', style: TextStyle(color: Colors.grey)),
        ),
      ]));
    }

    // Camera initialising
    if (!_camReady || _camCtrl == null) {
      return _card(Column(children: [
        const Text('📷', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        const Text('Starting Camera...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: _primaryColor),
        const SizedBox(height: 16),
        const Text('Please allow camera access when prompted.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _step = 2),
          child: const Text('Skip for now', style: TextStyle(color: Colors.grey)),
        ),
      ]));
    }

    // Live camera viewfinder
    return _card(Column(children: [
      const Text('🤳', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      const Text('Take a Selfie',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Position your face in the frame, then tap the button below.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),

      // Live viewfinder — same container style as QR scanner
      Container(
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primaryColor, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CameraPreview(_camCtrl!),
        ),
      ),

      const SizedBox(height: 20),

      // Capture button
      GestureDetector(
        onTap: _isLoading ? null : _captureSelfie,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isLoading ? Colors.grey.shade300 : _primaryColor,
            boxShadow: [BoxShadow(
                color: _primaryColor.withValues(alpha: 0.4),
                blurRadius: 12, spreadRadius: 2)],
          ),
          child: _isLoading
              ? const Center(child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
              : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
        ),
      ),
      const SizedBox(height: 10),
      const Text('Tap to capture', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => setState(() => _step = 2),
        child: const Text('Skip for now', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ),
    ]));
  }

  Widget _photoPlaceholder() => Container(
    width: 160, height: 160,
    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 2)),
    child: const Icon(Icons.person, size: 70, color: Colors.grey),
  );

  // ─── STEP 2: GPS ──────────────────────────────────────────────────────
  Widget _buildGPSStep() => _card(Column(children: [
    const Text('📍', style: TextStyle(fontSize: 52)),
    const SizedBox(height: 12),
    const Text('Get Your Location',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    const Text('Confirms you are physically in the classroom.',
        style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
    const SizedBox(height: 24),
    if (_latitude != null) ...[
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
          const SizedBox(width: 8),
          Text('${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32))),
        ]),
      ),
      const SizedBox(height: 16),
    ],
    _primaryBtn(
      label: _isLoading ? 'Locating...' : 'Get GPS Location',
      icon: Icons.my_location_rounded,
      loading: _isLoading, onTap: _isLoading ? null : _getLocation,
    ),
  ]));

  // ─── STEP 3: QR ───────────────────────────────────────────────────────
  Widget _buildQRStep() {
    final ctrl = _getScanner();
    return _card(Column(children: [
      const Text('📷', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      const Text('Scan Class QR Code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Allow camera access when prompted, then point at the QR code.',
          style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 20),

      Container(
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primaryColor, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MobileScanner(
            controller: ctrl,
            onDetect: (capture) {
              final b = capture.barcodes.firstOrNull;
              if (b?.rawValue != null) _onQRScanned(b!.rawValue!);
            },
            errorBuilder: (context, error, child) => Container(
              color: Colors.grey.shade50,
              child: Center(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text('Waiting for camera permission...',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(error.errorDetails?.message ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => ctrl.start(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor, foregroundColor: Colors.white),
                  ),
                ]),
              )),
            ),
          ),
        ),
      ),

      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text('Camera active — scanning for QR...',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: _showManualQR,
        icon: const Icon(Icons.keyboard_alt_outlined, size: 16),
        label: const Text('Enter code manually instead'),
      ),
    ]));
  }

  void _showManualQR() {
    final c = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Enter Class Code'),
      content: TextField(controller: c,
          decoration: const InputDecoration(
              hintText: 'e.g. CS101-2025', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (c.text.isNotEmpty) { Navigator.pop(context); _onQRScanned(c.text.trim()); }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor, foregroundColor: Colors.white),
          child: const Text('Confirm'),
        ),
      ],
    ));
  }

  // ─── STEP 4: Reflection ───────────────────────────────────────────────
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
            color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          _buildPhotoAvatar(),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_studentName ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(_studentEmail ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.verified_user, color: _primaryColor, size: 18),
        ]),
      ),
      const SizedBox(height: 16),

      _textField(ctrl: _prevTopicCtrl, label: 'What was covered last class?',
          hint: 'e.g. Introduction to Flutter widgets',
          icon: Icons.history_edu_outlined, maxLines: 2),
      const SizedBox(height: 14),
      _textField(ctrl: _expTopicCtrl, label: 'What do you expect to learn today?',
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
          onTap: _submitting ? null : _submitForm),
    ],
  ));

  Widget _buildPhotoAvatar() {
    if (_capturedPhoto == null) {
      return const CircleAvatar(radius: 20, backgroundColor: _primaryColor,
          child: Icon(Icons.person, color: Colors.white, size: 22));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: kIsWeb
          ? Image.network(_capturedPhoto!.path, width: 40, height: 40, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const CircleAvatar(radius: 20, backgroundColor: _primaryColor,
                      child: Icon(Icons.person, color: Colors.white, size: 22)))
          : Image.file(File(_capturedPhoto!.path), width: 40, height: 40, fit: BoxFit.cover),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────
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
              border: Border.all(color: sel ? _primaryColor : Colors.grey.shade300),
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
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: true, fillColor: const Color(0xFFF8FAFF),
        ),
      ),
    ],
  );

  Widget _primaryBtn({
    required String label, IconData? icon,
    bool loading = false, VoidCallback? onTap,
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
        backgroundColor: _primaryColor, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _outlineBtn({required String label, required IconData icon, VoidCallback? onTap}) =>
      OutlinedButton.icon(
        onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: _primaryColor),
          foregroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _infoBadge(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: _primaryColor),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey),
          overflow: TextOverflow.ellipsis),
    ]),
  );
}