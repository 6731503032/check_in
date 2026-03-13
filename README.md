# Class Check-In App

A Flutter mobile app for university class attendance. Students check in with GPS, QR scan, and a short reflection. At the end of class, they check out the same way.

---

## Features

- **Check-in** — Identity → Selfie → GPS → QR Scan → Pre-class reflection
- **Finish Class** — GPS → QR Scan → Post-class reflection + mood tracking
- **History** — Full attendance log with filters and expandable records
- Works on **Android, iOS, and Web** (Chrome)

---

## Tech Stack

| | |
|---|---|
| Framework | Flutter (Dart) |
| Local Storage | SQLite (mobile) / In-memory (web) |
| Cloud | Firebase Firestore |
| GPS | geolocator |
| QR / Camera | mobile_scanner, camera |

---

## Setup

**1. Clone and install dependencies**
```bash
flutter pub get
```

**2. Configure Firebase**
```bash
flutterfire configure
```
This generates `lib/firebase_options.dart`. Follow the CLI prompts for Android, iOS, and Web.

**3. Run**
```bash
# Web
flutter run -d chrome

# Android
flutter run -d android
```

---

## Project Structure

```
lib/
├── main.dart
├── models/
│   └── attendance_model.dart
├── screens/
│   ├── home_screen.dart
│   ├── checkin_screen.dart
│   ├── finish_screen.dart
│   └── history_screen.dart
└── services/
    ├── storage_service.dart   # web/mobile storage abstraction
    ├── db_service.dart        # SQLite (mobile only)
    └── firebase_service.dart  # Firestore sync
```

---

## Notes

- Web storage is **session-only** — data resets on page refresh
- Email must end in `@lamduan.mfu.ac.th` to check in
- Firebase sync is best-effort — app works offline via local storage