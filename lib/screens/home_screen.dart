// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../services/storage_service.dart';
import 'checkin_screen.dart';
import 'finish_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AttendanceRecord? _activeRecord;
  List<AttendanceRecord> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final active = await StorageService.getActiveRecord();
      final history = await StorageService.getAllRecords();
      setState(() { _activeRecord = active; _history = history; });
    } catch (e) {
      debugPrint('DB error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _history.where((r) => r.finishTime != null).length;
    final total = _history.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // ── Header ──────────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: const Color(0xFF0D47A1),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🎓', style: TextStyle(fontSize: 32)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Class Check-in',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                            DateFormat('EEEE, d MMMM yyyy')
                                                .format(DateTime.now()),
                                            style: const TextStyle(
                                                color: Colors.white70, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // History button
                                    IconButton(
                                      onPressed: () async {
                                        await Navigator.push(context,
                                            MaterialPageRoute(
                                                builder: (_) => const HistoryScreen()));
                                        _loadData();
                                      },
                                      icon: const Icon(Icons.history_rounded,
                                          color: Colors.white, size: 26),
                                      tooltip: 'View all history',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Stats row
                                Row(
                                  children: [
                                    _statChip('📅', '$total', 'Total'),
                                    const SizedBox(width: 10),
                                    _statChip('✅', '$completed', 'Completed'),
                                    const SizedBox(width: 10),
                                    _statChip('⏳', '${total - completed}', 'In Progress'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                        // ── Active session card ────────────────────────────
                        _buildStatusCard(),
                        const SizedBox(height: 16),

                        // ── Action buttons ─────────────────────────────────
                        _buildActionButton(
                          label: 'Check-in to Class',
                          subtitle: 'GPS + QR + Reflection',
                          icon: Icons.login_rounded,
                          color: const Color(0xFF1565C0),
                          disabled: _activeRecord != null,
                          disabledReason: 'Already checked in',
                          onTap: () async {
                            await Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const CheckinScreen()));
                            _loadData();
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          label: 'Finish Class',
                          subtitle: 'GPS + QR + Post-reflection',
                          icon: Icons.flag_rounded,
                          color: const Color(0xFF2E7D32),
                          disabled: _activeRecord == null,
                          disabledReason: 'Check in first',
                          onTap: () async {
                            await Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        FinishScreen(record: _activeRecord!)));
                            _loadData();
                          },
                        ),

                        // ── Recent activity ────────────────────────────────
                        if (_history.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Recent Activity',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A237E))),
                              TextButton(
                                onPressed: () async {
                                  await Navigator.push(context,
                                      MaterialPageRoute(
                                          builder: (_) => const HistoryScreen()));
                                  _loadData();
                                },
                                child: const Text('See all →',
                                    style: TextStyle(color: Color(0xFF1565C0))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._history.take(3).map(_buildHistoryCard),
                        ] else ...[
                          const SizedBox(height: 40),
                          _buildEmptyState(),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Small stat chip in header ──────────────────────────────────────────
  Widget _statChip(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$emoji $value',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Status card ────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final isIn = _activeRecord != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isIn ? const Color(0xFF4CAF50) : const Color(0xFFBBDEFB),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isIn ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(isIn ? '✅' : '📋',
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIn ? 'Currently Checked In' : 'Not Checked In',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isIn
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 2),
                if (isIn) ...[
                  Text(
                    'Since ${DateFormat('HH:mm').format(_activeRecord!.checkInTime)} · ${_activeRecord!.studentId}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  // Duration indicator
                  _buildDurationBadge(_activeRecord!.checkInTime),
                ] else
                  const Text('Tap Check-in when you arrive in class',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationBadge(DateTime checkIn) {
    final diff = DateTime.now().difference(checkIn);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final label = h > 0 ? '${h}h ${m}m in class' : '${m}m in class';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('⏱ $label',
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500)),
    );
  }

  // ── Action button ──────────────────────────────────────────────────────
  Widget _buildActionButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool disabled,
    required String disabledReason,
    required VoidCallback onTap,
  }) {
    return Material(
      color: disabled ? Colors.grey.shade200 : color,
      borderRadius: BorderRadius.circular(14),
      elevation: disabled ? 0 : 2,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: disabled
                      ? Colors.grey.shade300
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: disabled ? Colors.grey : Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          color: disabled ? Colors.grey : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        )),
                    Text(disabled ? disabledReason : subtitle,
                        style: TextStyle(
                          color: disabled
                              ? Colors.grey.shade400
                              : Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: disabled
                      ? Colors.grey.shade400
                      : Colors.white.withValues(alpha: 0.7),
                  size: 15),
            ],
          ),
        ),
      ),
    );
  }

  // ── History card ───────────────────────────────────────────────────────
  Widget _buildHistoryCard(AttendanceRecord r) {
    final isComplete = r.finishTime != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left color bar
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.studentId,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isComplete
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isComplete ? '✅ Done' : '⏳ Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isComplete
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy · HH:mm').format(r.checkInTime),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (r.qrData.isNotEmpty)
                  Text('📷 ${r.qrData}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                // Mood indicator
                const SizedBox(height: 4),
                Row(children: [
                  Text(_moodEmoji(r.moodBefore),
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(r.studentEmail,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const Text('📭', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text('No check-ins yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 6),
          const Text('Tap Check-in to record your first attendance.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

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
}