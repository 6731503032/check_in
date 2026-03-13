# Product Requirement Document (PRD)
## Smart Class Check-in & Learning Reflection App

---

## 1. Problem Statement

Lecturer find it hard to accurately verify student attendance and participation during the lecture. Sign-in system such as google form allows students to upload images taken previously and allow for remote check-in.THese problems are solve through this app. This app allows GPS location and real-time camera to access if the student is in class or not.

Lecturer find it difficult to prepare course materials according to student's needs.
This app allows lecturer to see the pre-class and post-class reflection from students which they can use to improve their lecture and teaching quality in the long run.

---

## 2. Target Users

- **Primary:** University students checking in and out of class
- **Secondary:** Instructors / Admin (viewing check-in data via Firebase)

---

## 3. Feature List

| # | Feature | Description |
|---|---------|-------------|
| 1 | GPS Check-in | Records student's GPS coordinates on check-in |
| 2 | QR Code Scan | Student scans classroom QR code to verify location |
| 3 | Pre-class Reflection | Student fills in previous topic, expected topic, and mood |
| 4 | GPS Check-out | Records GPS on class completion |
| 5 | QR Re-scan | Student re-scans QR at end of class |
| 6 | Post-class Reflection | Student fills in what they learned and class feedback |
| 7 | Local Storage | Data saved using SQLite for offline support |
| 8 | Firebase Sync | Data synced to Firestore cloud database |

---

## 4. User Flow

```
[App Opens]
     |
[Home Screen]
     |
  +--+--+
  |     |
[Check-in]   [Finish Class]
  |               |
[Get GPS]     [Get GPS]
  |               |
[Scan QR]     [Scan QR]
  |               |
[Fill Form]   [Fill Form]
  |               |
[Save to SQLite + Firebase]
```

---

## 5. Data Fields

### Check-in Record
| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique record ID (UUID) |
| studentId | String | Student identifier |
| timestamp | DateTime | Date and time of check-in |
| latitude | double | GPS latitude |
| longitude | double | GPS longitude |
| qrData | String | Data from scanned QR code |
| previousTopic | String | What was covered last class |
| expectedTopic | String | What student expects to learn today |
| moodBefore | int | Mood score 1–5 |

### Check-out Record
| Field | Type | Description |
|-------|------|-------------|
| id | String | Links to check-in record |
| finishTimestamp | DateTime | Date and time of finish |
| finishLatitude | double | GPS latitude at finish |
| finishLongitude | double | GPS longitude at finish |
| finishQrData | String | QR scan at end of class |
| learned | String | What the student learned |
| feedback | String | Feedback about class/instructor |

---

## 6. Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Local Storage | SQLite (sqflite) |
| Cloud Database | Firebase Firestore |
| Hosting | Firebase Hosting |
| GPS | geolocator package |
| QR Scanning | mobile_scanner package |

---

## 7. Screens Summary

1. **Home Screen** — Entry point, shows Check-in and Finish Class buttons
2. **Check-in Screen** — GPS + QR + pre-class form
3. **Finish Class Screen** — GPS + QR + post-class form

---

*Version: 1.0 | Target: MVP Prototype*