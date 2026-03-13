// lib/services/storage_service.dart
// Mobile: SQLite via sqflite (with timeout guards)
// Web:    Static singleton in-memory list (persists across Navigator push/pop)

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../models/attendance_model.dart';
import 'db_service.dart';

class StorageService {
  // Static final — one list for the entire app session, survives all navigation
  static final List<AttendanceRecord> _webRecords = [];

  // ── Insert ────────────────────────────────────────────────────────────
  static Future<void> insertRecord(AttendanceRecord record) async {
    if (kIsWeb) {
      _webRecords.removeWhere((r) => r.id == record.id); // idempotent
      _webRecords.insert(0, record);
      debugPrint('Web store: inserted ${record.id} — total ${_webRecords.length}');
      return;
    }
    try {
      await DBService.insertRecord(record)
          .timeout(const Duration(seconds: 8), onTimeout: () {
        debugPrint('DB insertRecord timeout');
      });
    } catch (e) {
      debugPrint('DB insertRecord error: $e');
    }
  }

  // ── Update ────────────────────────────────────────────────────────────
  static Future<void> updateRecord(AttendanceRecord record) async {
    if (kIsWeb) {
      final idx = _webRecords.indexWhere((r) => r.id == record.id);
      if (idx != -1) {
        _webRecords[idx] = record;
      } else {
        _webRecords.insert(0, record); // fallback: insert if not found
      }
      debugPrint('Web store: updated ${record.id}');
      return;
    }
    try {
      await DBService.updateRecord(record)
          .timeout(const Duration(seconds: 8), onTimeout: () {
        debugPrint('DB updateRecord timeout');
      });
    } catch (e) {
      debugPrint('DB updateRecord error: $e');
    }
  }

  // ── Get all ───────────────────────────────────────────────────────────
  static Future<List<AttendanceRecord>> getAllRecords() async {
    if (kIsWeb) {
      final sorted = List<AttendanceRecord>.from(_webRecords)
        ..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      debugPrint('Web store: fetched ${sorted.length} records');
      return sorted;
    }
    try {
      return await DBService.getAllRecords()
          .timeout(const Duration(seconds: 8), onTimeout: () => []);
    } catch (e) {
      debugPrint('DB getAllRecords error: $e');
      return [];
    }
  }

  // ── Get active (no finishTime) ────────────────────────────────────────
  static Future<AttendanceRecord?> getActiveRecord() async {
    if (kIsWeb) {
      try {
        return _webRecords.firstWhere((r) => r.finishTime == null);
      } catch (_) {
        return null; // no active record — safe fallback
      }
    }
    try {
      return await DBService.getActiveRecord()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
    } catch (e) {
      debugPrint('DB getActiveRecord error: $e');
      return null;
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────
  static Future<void> deleteRecord(String id) async {
    if (kIsWeb) {
      _webRecords.removeWhere((r) => r.id == id);
      return;
    }
    try {
      await DBService.deleteRecord(id)
          .timeout(const Duration(seconds: 8), onTimeout: () {
        debugPrint('DB deleteRecord timeout');
      });
    } catch (e) {
      debugPrint('DB deleteRecord error: $e');
    }
  }
}