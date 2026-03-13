// lib/models/attendance_model.dart

class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentEmail;       // e.g. 65012345@lamduan.mfu.ac.th
  final DateTime checkInTime;
  final double latitude;
  final double longitude;
  final String qrData;
  final String previousTopic;
  final String expectedTopic;
  final int moodBefore;
  final String? facePhotoPath;     // Local path on mobile

  DateTime? finishTime;
  double? finishLatitude;
  double? finishLongitude;
  String? finishQrData;
  String? learned;
  String? feedback;
  int? moodAfter;       // mood score after class

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

  Map<String, dynamic> toMap() => {
    'id': id,
    'studentId': studentId,
    'studentEmail': studentEmail,
    'checkInTime': checkInTime.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'qrData': qrData,
    'previousTopic': previousTopic,
    'expectedTopic': expectedTopic,
    'moodBefore': moodBefore,
    'facePhotoPath': facePhotoPath,
    'finishTime': finishTime?.toIso8601String(),
    'finishLatitude': finishLatitude,
    'finishLongitude': finishLongitude,
    'finishQrData': finishQrData,
    'learned': learned,
    'feedback': feedback,
  };

  Map<String, dynamic> toFirebaseMap() => {
    'id': id,
    'studentId': studentId,
    'studentEmail': studentEmail,
    'checkInTime': checkInTime.toIso8601String(),
    'location': {'latitude': latitude, 'longitude': longitude},
    'qrData': qrData,
    'reflection': {
      'previousTopic': previousTopic,
      'expectedTopic': expectedTopic,
      'moodBefore': moodBefore,
    },
    'finish': finishTime != null ? {
      'finishTime': finishTime!.toIso8601String(),
      'location': {'latitude': finishLatitude, 'longitude': finishLongitude},
      'qrData': finishQrData,
      'learned': learned,
      'feedback': feedback,
    } : null,
  };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) => AttendanceRecord(
    id: map['id'],
    studentId: map['studentId'],
    studentEmail: map['studentEmail'] ?? '',
    checkInTime: DateTime.parse(map['checkInTime']),
    latitude: map['latitude'],
    longitude: map['longitude'],
    qrData: map['qrData'],
    previousTopic: map['previousTopic'],
    expectedTopic: map['expectedTopic'],
    moodBefore: map['moodBefore'],
    facePhotoPath: map['facePhotoPath'],
    finishTime: map['finishTime'] != null ? DateTime.parse(map['finishTime']) : null,
    finishLatitude: map['finishLatitude'],
    finishLongitude: map['finishLongitude'],
    finishQrData: map['finishQrData'],
    learned: map['learned'],
    feedback: map['feedback'],
    moodAfter: map['moodAfter'],
  );

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
}