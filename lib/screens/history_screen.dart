// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AttendanceRecord> _all = [];
  List<AttendanceRecord> _filtered = [];
  bool _loading = true;
  String _filter = 'all'; // all | done | active

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final records = await StorageService.getAllRecords();
      setState(() {
        _all = records;
        _applyFilter();
      });
    } catch (e) {
      debugPrint('History load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      switch (_filter) {
        case 'done':
          _filtered = _all.where((r) => r.finishTime != null).toList();
          break;
        case 'active':
          _filtered = _all.where((r) => r.finishTime == null).toList();
          break;
        default:
          _filtered = List.from(_all);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final completed = _all.where((r) => r.finishTime != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text('Attendance History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary banner
                Container(
                  color: const Color(0xFF1565C0),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _summaryTile('Total\nSessions', '${_all.length}'),
                      _summaryTile('Completed', '$completed'),
                      _summaryTile('Attendance\nRate',
                          _all.isEmpty
                              ? '—'
                              : '${(completed / _all.length * 100).round()}%'),
                    ],
                  ),
                ),

                // Filter tabs
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _filterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _filterChip('✅ Completed', 'done'),
                      const SizedBox(width: 8),
                      _filterChip('⏳ Active', 'active'),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('📭', style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text('No records found',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 15)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _buildDetailCard(_filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryTile(String label, String value) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); _applyFilter(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1565C0) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(AttendanceRecord r) {
    final isComplete = r.finishTime != null;
    Duration? duration;
    if (isComplete) {
      duration = r.finishTime!.difference(r.checkInTime);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(isComplete ? '✅' : '⏳',
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          title: Text(r.studentId,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEE, dd MMM yyyy · HH:mm').format(r.checkInTime),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Row(children: [
                Text(_moodEmoji(r.moodBefore),
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(isComplete ? '· ${_formatDuration(duration!)}' : '· In Progress',
                    style: TextStyle(
                      fontSize: 11,
                      color: isComplete
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                    )),
              ]),
            ],
          ),
          children: [
            const Divider(),
            const SizedBox(height: 6),
            // Check-in details
            _sectionHeader('📥 Check-in Details'),
            _detailRow(Icons.email_outlined, 'Email', r.studentEmail),
            _detailRow(Icons.location_on_outlined, 'Location',
                '${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}'),
            _detailRow(Icons.qr_code, 'QR Code', r.qrData),
            _detailRow(Icons.history_edu_outlined, 'Last Topic', r.previousTopic),
            _detailRow(Icons.lightbulb_outline, 'Expected Today', r.expectedTopic),
            _detailRow(_moodIcon(r.moodBefore), 'Mood Before', r.moodLabel),

            if (isComplete) ...[
              const SizedBox(height: 10),
              _sectionHeader('📤 Check-out Details'),
              _detailRow(Icons.access_time, 'Finished',
                  DateFormat('HH:mm').format(r.finishTime!)),
              if (r.finishLatitude != null)
                _detailRow(Icons.location_on_outlined, 'Exit Location',
                    '${r.finishLatitude!.toStringAsFixed(5)}, ${r.finishLongitude!.toStringAsFixed(5)}'),
              if (r.finishQrData != null)
                _detailRow(Icons.qr_code, 'Exit QR', r.finishQrData!),
              if (r.learned != null)
                _detailRow(Icons.school_outlined, 'What I Learned', r.learned!),
              if (r.feedback != null)
                _detailRow(Icons.rate_review_outlined, 'Feedback', r.feedback!),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Text('Total time in class: ${_formatDuration(duration!)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF1565C0))),
  );

  Widget _detailRow(dynamic icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon is IconData
            ? Icon(icon, size: 15, color: Colors.grey)
            : Text(icon as String, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.visible),
        ),
      ],
    ),
  );

  String _moodEmoji(int mood) {
    switch (mood) {
      case 1: return '😡';
      case 2: return '🙁';
      case 3: return '😐';
      case 4: return '🙂';
      case 5: return '😄';
      default: return '😐';
    }
  }

  IconData _moodIcon(int mood) => Icons.mood;

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}