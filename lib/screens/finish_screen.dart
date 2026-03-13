// lib/screens/finish_screen.dart
// Steps: 0=GPS  1=QR  2=Reflection (includes mood after class)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/attendance_model.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';

class FinishScreen extends StatefulWidget {
  final AttendanceRecord record;
  const FinishScreen({super.key, required this.record});
  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  int _step = 0;
  static const _primaryColor = Color(0xFF2E7D32);
  final _stepLabels = ['GPS', 'QR', 'Reflection'];

  double? _latitude;
  double? _longitude;
  String? _qrData;
  MobileScannerController? _scannerCtrl;

  final _learnedCtrl  = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  int _moodAfter = 3;

  bool _isLoading  = false;
  bool _submitting = false;
  bool _errorShowing = false;

  @override
  void dispose() {
    _learnedCtrl.dispose();
    _feedbackCtrl.dispose();
    _scannerCtrl?.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step > 0) {
      if (_step == 1) { _scannerCtrl?.stop(); _scannerCtrl?.dispose(); _scannerCtrl = null; }
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

  // ── GPS ───────────────────────────────────────────────────────────────
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
      setState(() { _latitude = pos.latitude; _longitude = pos.longitude; _step = 1; });
    } catch (e) {
      _showError('Could not get location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── QR ────────────────────────────────────────────────────────────────
  void _initScanner() {
    _scannerCtrl ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  void _onQRScanned(String data) {
    _scannerCtrl?.stop();
    setState(() { _qrData = data; _step = 2; });
  }

  // ── Submit ────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (_learnedCtrl.text.isEmpty || _feedbackCtrl.text.isEmpty) {
      _showError('Please fill in all fields.'); return;
    }
    setState(() => _submitting = true);
    try {
      final updated = widget.record
        ..finishTime     = DateTime.now()
        ..finishLatitude  = _latitude
        ..finishLongitude = _longitude
        ..finishQrData    = _qrData
        ..learned         = _learnedCtrl.text.trim()
        ..feedback        = _feedbackCtrl.text.trim()
        ..moodAfter       = _moodAfter;

      // Web: skip SQLite, mobile: save locally with timeout guard
      if (!kIsWeb) {
        await StorageService.updateRecord(updated)
            .timeout(const Duration(seconds: 8), onTimeout: () {
          debugPrint('Local DB update timeout — continuing');
        });
      } else {
        await StorageService.updateRecord(updated);
      }

      // Firebase sync — best-effort
      try {
        await FirebaseService.saveRecord(updated)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Firebase sync failed (finish): $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Class finished! Well done!'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────
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
            title: const Text('Finish Class',
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
                      const Icon(Icons.arrow_back_ios_rounded,
                          size: 12, color: _primaryColor),
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

        // Full-screen submit overlay
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
                    CircularProgressIndicator(color: Color(0xFF2E7D32)),
                    SizedBox(height: 16),
                    Text('Saving class record...',
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

  Widget _buildProgressBar() => Container(
    color: _primaryColor,
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
    child: Row(
      children: List.generate(_stepLabels.length, (i) {
        final isActive = _step == i;
        final isDone   = _step > i;
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
      case 0: return _buildGPSStep();
      case 1: return _buildQRStep();
      case 2: return _buildFormStep();
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

  // ─── GPS ──────────────────────────────────────────────────────────────
  Widget _buildGPSStep() => _card(Column(children: [
    const Text('📍', style: TextStyle(fontSize: 52)),
    const SizedBox(height: 12),
    const Text('Confirm Your Location',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    const Text('Records your location at the end of class.',
        style: TextStyle(color: Colors.grey, fontSize: 13),
        textAlign: TextAlign.center),
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
    _primaryBtn(label: _isLoading ? 'Locating...' : 'Get GPS Location',
        icon: Icons.my_location_rounded,
        loading: _isLoading, onTap: _isLoading ? null : _getLocation),
  ]));

  // ─── QR ───────────────────────────────────────────────────────────────
  Widget _buildQRStep() {
    _initScanner();
    return _card(Column(children: [
      const Text('📷', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      const Text('Scan QR Code Again',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Allow camera when prompted. Confirms you stayed until the end.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center),
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
            controller: _scannerCtrl,
            onDetect: (capture) {
              final b = capture.barcodes.firstOrNull;
              if (b?.rawValue != null) _onQRScanned(b!.rawValue!);
            },
            errorBuilder: (_, error, __) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.no_photography_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('Camera not available',
                    style: TextStyle(color: Colors.grey)),
                Text(error.errorDetails?.message ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _scannerCtrl?.start(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor, foregroundColor: Colors.white),
                ),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 8, height: 8,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text('Camera active — scanning...',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: _showManualEntry,
        icon: const Icon(Icons.keyboard_alt_outlined, size: 16),
        label: const Text('Enter code manually instead'),
      ),
    ]));
  }

  void _showManualEntry() {
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

  // ─── Reflection ───────────────────────────────────────────────────────
  Widget _buildFormStep() => _card(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Center(child: Text('📝', style: TextStyle(fontSize: 52))),
      const SizedBox(height: 12),
      const Center(child: Text('Post-class Reflection',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      const SizedBox(height: 4),
      const Center(child: Text('Great job! Tell us about your experience.',
          style: TextStyle(color: Colors.grey, fontSize: 13))),
      const SizedBox(height: 20),

      // Mood before (read-only)
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text(_moodEmoji(widget.record.moodBefore),
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mood when you arrived',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text(widget.record.moodLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),

      _textField(ctrl: _learnedCtrl,
          label: 'What did you learn today?',
          hint: 'e.g. I learned how to use StreamBuilder...',
          icon: Icons.school_outlined, maxLines: 3),
      const SizedBox(height: 14),
      _textField(ctrl: _feedbackCtrl,
          label: 'Feedback about the class or instructor:',
          hint: 'e.g. The examples were very clear and helpful...',
          icon: Icons.rate_review_outlined, maxLines: 3),
      const SizedBox(height: 20),

      const Text('How are you feeling after class?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 10),
      _moodSelector(_moodAfter, (v) => setState(() => _moodAfter = v)),
      const SizedBox(height: 20),

      // Mood comparison
      if (widget.record.moodBefore != _moodAfter)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _moodAfter > widget.record.moodBefore
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Text(_moodEmoji(widget.record.moodBefore),
                style: const TextStyle(fontSize: 20)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey)),
            Text(_moodEmoji(_moodAfter), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _moodAfter > widget.record.moodBefore
                    ? '😊 Mood improved after class!'
                    : '😕 Mood dropped — hope next class is better!',
                style: TextStyle(fontSize: 12,
                    color: _moodAfter > widget.record.moodBefore
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE65100)),
              ),
            ),
          ]),
        ),

      const SizedBox(height: 16),
      if (_qrData != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.qr_code, size: 16, color: Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            Expanded(child: Text('QR: $_qrData',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis)),
          ]),
        ),
      const SizedBox(height: 20),

      _primaryBtn(label: 'Submit & Finish Class', icon: Icons.flag_rounded,
          loading: _submitting, onTap: _submitting ? null : _submitForm),
    ],
  ));

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
        final sel   = current == score;
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
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, maxLines: maxLines,
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

  String _moodEmoji(int mood) {
    switch (mood) {
      case 1: return '😡'; case 2: return '🙁'; case 3: return '😐';
      case 4: return '🙂'; case 5: return '😄'; default: return '😐';
    }
  }
}