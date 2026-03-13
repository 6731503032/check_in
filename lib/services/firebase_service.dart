// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance_model.dart';

class FirebaseService {
  static bool get _ready {
    try {
      Firebase.app(); // throws if not initialized
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveRecord(AttendanceRecord record) async {
    if (!_ready) { debugPrint('Firebase not ready — skipping sync'); return; }
    try {
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(record.id)
          .set(record.toFirebaseMap());
    } catch (e) {
      debugPrint('Firebase save error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllRecords() async {
    if (!_ready) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .orderBy('checkInTime', descending: true)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      debugPrint('Firebase fetch error: $e');
      return [];
    }
  }
}