// lib/services/db_service.dart
// SQLite — only used on Android/iOS (not web)

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/attendance_model.dart';

class DBService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'checkin.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE attendance (
            id TEXT PRIMARY KEY,
            studentId TEXT,
            studentEmail TEXT,
            checkInTime TEXT,
            latitude REAL,
            longitude REAL,
            qrData TEXT,
            previousTopic TEXT,
            expectedTopic TEXT,
            moodBefore INTEGER,
            moodAfter INTEGER,
            facePhotoPath TEXT,
            finishTime TEXT,
            finishLatitude REAL,
            finishLongitude REAL,
            finishQrData TEXT,
            learned TEXT,
            feedback TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE attendance ADD COLUMN studentEmail TEXT');
          await db.execute('ALTER TABLE attendance ADD COLUMN facePhotoPath TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE attendance ADD COLUMN moodAfter INTEGER');
        }
      },
    );
  }

  static Future<void> insertRecord(AttendanceRecord record) async {
    final db = await database;
    await db.insert('attendance', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateRecord(AttendanceRecord record) async {
    final db = await database;
    await db.update('attendance', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  static Future<List<AttendanceRecord>> getAllRecords() async {
    final db = await database;
    final maps = await db.query('attendance', orderBy: 'checkInTime DESC');
    return maps.map((m) => AttendanceRecord.fromMap(m)).toList();
  }

  static Future<AttendanceRecord?> getActiveRecord() async {
    final db = await database;
    final maps = await db.query('attendance',
        where: 'finishTime IS NULL',
        orderBy: 'checkInTime DESC',
        limit: 1);
    if (maps.isEmpty) return null;
    return AttendanceRecord.fromMap(maps.first);
  }

  static Future<void> deleteRecord(String id) async {
    final db = await database;
    await db.delete('attendance', where: 'id = ?', whereArgs: [id]);
  }
}