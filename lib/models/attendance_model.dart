// lib/models/attendance_model.dart

class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentEmail;
  final DateTime checkInTime;
  final double latitude;
  final double longitude;
  final String qrData;
  final String previousTopic;
  final String expectedTopic;
  final int moodBefore;
  final String? facePhotoPath;

  DateTime? finishTime;
  double? finishLatitude;
  double? finishLongitude;
  String? finishQrData;
  String? learned;
  String? feedback;
  int? moodAfter;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentEmail,
    required this.checkInTime,
    required this.latitude,
    required this.longitude,
    required this.qrData,
    required this.previousTopic,
    required this.expectedTopic,
    required this.moodBefore,
    this.facePhotoPath,
    this.finishTime,
    this.finishLatitude,
    this.finishLongitude,
    this.finishQrData,
    this.learned,
    this.feedback,
    this.moodAfter,
  });

  // ── SQLite serialisation ───────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'id':              id,
    'studentId':       studentId,
    'studentEmail':    studentEmail,
    'checkInTime':     checkInTime.toIso8601String(),
    'latitude':        latitude,
    'longitude':       longitude,
    'qrData':          qrData,
    'previousTopic':   previousTopic,
    'expectedTopic':   expectedTopic,
    'moodBefore':      moodBefore,
    'moodAfter':       moodAfter,       // was missing
    'facePhotoPath':   facePhotoPath,
    'finishTime':      finishTime?.toIso8601String(),
    'finishLatitude':  finishLatitude,
    'finishLongitude': finishLongitude,
    'finishQrData':    finishQrData,
    'learned':         learned,
    'feedback':        feedback,
  };

  // ── Firestore serialisation ────────────────────────────────────────────
  Map<String, dynamic> toFirebaseMap() => {
    'id':           id,
    'studentId':    studentId,
    'studentEmail': studentEmail,
    'checkInTime':  checkInTime.toIso8601String(),
    'location': {'latitude': latitude, 'longitude': longitude},
    'qrData':       qrData,
    'reflection': {
      'previousTopic': previousTopic,
      'expectedTopic': expectedTopic,
      'moodBefore':    moodBefore,
    },
    'finish': finishTime != null ? {
      'finishTime': finishTime!.toIso8601String(),
      'location': {'latitude': finishLatitude, 'longitude': finishLongitude},
      'qrData':    finishQrData,
      'learned':   learned,
      'feedback':  feedback,
      'moodAfter': moodAfter,           // was missing
    } : null,
  };

  // ── Deserialisation ───────────────────────────────────────────────────
  factory AttendanceRecord.fromMap(Map<String, dynamic> map) => AttendanceRecord(
    id:              map['id'] as String,
    studentId:       map['studentId'] as String,
    studentEmail:    map['studentEmail'] as String? ?? '',
    checkInTime:     DateTime.parse(map['checkInTime'] as String),
    latitude:        (map['latitude'] as num).toDouble(),
    longitude:       (map['longitude'] as num).toDouble(),
    qrData:          map['qrData'] as String,
    previousTopic:   map['previousTopic'] as String,
    expectedTopic:   map['expectedTopic'] as String,
    moodBefore:      map['moodBefore'] as int,
    moodAfter:       map['moodAfter'] as int?,
    facePhotoPath:   map['facePhotoPath'] as String?,
    finishTime:      map['finishTime'] != null
                       ? DateTime.parse(map['finishTime'] as String)
                       : null,
    finishLatitude:  (map['finishLatitude'] as num?)?.toDouble(),
    finishLongitude: (map['finishLongitude'] as num?)?.toDouble(),
    finishQrData:    map['finishQrData'] as String?,
    learned:         map['learned'] as String?,
    feedback:        map['feedback'] as String?,
  );

  // ── copyWith — creates a new object for safe updates ──────────────────
  AttendanceRecord copyWith({
    DateTime? finishTime,
    double?   finishLatitude,
    double?   finishLongitude,
    String?   finishQrData,
    String?   learned,
    String?   feedback,
    int?      moodAfter,
  }) => AttendanceRecord(
    id:              id,
    studentId:       studentId,
    studentEmail:    studentEmail,
    checkInTime:     checkInTime,
    latitude:        latitude,
    longitude:       longitude,
    qrData:          qrData,
    previousTopic:   previousTopic,
    expectedTopic:   expectedTopic,
    moodBefore:      moodBefore,
    facePhotoPath:   facePhotoPath,
    finishTime:      finishTime      ?? this.finishTime,
    finishLatitude:  finishLatitude  ?? this.finishLatitude,
    finishLongitude: finishLongitude ?? this.finishLongitude,
    finishQrData:    finishQrData    ?? this.finishQrData,
    learned:         learned         ?? this.learned,
    feedback:        feedback        ?? this.feedback,
    moodAfter:       moodAfter       ?? this.moodAfter,
  );

  // ── Helpers ───────────────────────────────────────────────────────────
  bool get isComplete => finishTime != null;

  String get moodLabel {
    switch (moodBefore) {
      case 1: return '😡 Very Negative';
      case 2: return '🙁 Negative';
      case 3: return '😐 Neutral';
      case 4: return '🙂 Positive';
      case 5: return '😄 Very Positive';
      default: return 'Unknown';
    }
  }

  String get moodAfterLabel {
    switch (moodAfter) {
      case 1: return '😡 Very Negative';
      case 2: return '🙁 Negative';
      case 3: return '😐 Neutral';
      case 4: return '🙂 Positive';
      case 5: return '😄 Very Positive';
      default: return 'Not recorded';
    }
  }
}