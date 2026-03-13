// lib/services/storage_service.dart
// Abstracts local storage — uses SQLite on mobile, in-memory on web.

import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/attendance_model.dart';
import 'db_service.dart';

class StorageService {
  // In-memory fallback for web (cleared on page refresh)
  static final List<AttendanceRecord> _webRecords = [];

  static Future<void> insertRecord(AttendanceRecord record) async {
    if (kIsWeb) {
      _webRecords.insert(0, record);
    } else {
      await DBService.insertRecord(record);
    }
  }

  static Future<void> updateRecord(AttendanceRecord record) async {
    if (kIsWeb) {
      final idx = _webRecords.indexWhere((r) => r.id == record.id);
      if (idx != -1) _webRecords[idx] = record;
    } else {
      await DBService.updateRecord(record);
    }
  }

  static Future<List<AttendanceRecord>> getAllRecords() async {
    if (kIsWeb) return List.from(_webRecords);
    return DBService.getAllRecords();
  }

  static Future<AttendanceRecord?> getActiveRecord() async {
    if (kIsWeb) {
      try {
        return _webRecords.firstWhere((r) => r.finishTime == null);
      } catch (_) {
        return null;
      }
    }
    return DBService.getActiveRecord();
  }
}