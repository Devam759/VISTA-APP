# 🏰 VISTA - Advanced Hostel Management System

VISTA (Virtual Intelligent Student Tracking & Attendance) is a professional, secure, and fully automated Flutter application designed for university hostel management. It streamlines student registrations, leave requests, complaint management, and attendance using cutting-edge AI and real-time cloud technology.

---

## 🌟 Key Features

### 👤 Multi-Role Ecosystem
- **Students**: Apply for hostel membership, request leaves, and track complaints.
- **Wardens**: Manage specific hostel blocks (BH1, BH2, GH1, GH2), approve students, and manage requests.
- **Head Warden**: High-level oversight with escalated complaint management.

### 🎭 AI Face Recognition Attendance
- **MobileFaceNet Integration**: Uses high-performance TFLite models for precise face matching.
- **Liveness Detection**: Anti-spoofing mechanism requires a **blink** to verify the user is physically present.
- **Biometric Security**: Face embeddings are shielded by strict Firestore production-grade rules.

### 🔔 Automated Notification Engine
- **GitHub Watcher**: A serverless Node.js engine that monitors Firestore every 10 minutes (running on GitHub Actions).
- **Push Notifications (FCM)**: Students and Wardens get real-time alerts for:
    - New registration applications.
    - Leave/Complaint status updates.
    - **Nightly Attendance Reminders** at 10:00 PM and 10:20 PM IST.
- **Zero-Cost Design**: Operates without the need for expensive Firebase paid plans.

### 🔒 Hardened Security
- **Production Firestore Rules**: Role-Based Access Control (RBAC) specifically protects biometric data and student privacy.
- **Code Obfuscation**: Release builds are hardened against reverse-engineering.
- **Secure Signing**: Uses a professional Keystore management system for release integrity.

---

## 🛠️ Technology Stack

- **Frontend**: Flutter (Dart)
- **State Management**: Provider (MVVM Architecture)
- **Backend**: Firebase (Auth, Firestore, FCM, Storage)
- **AI/ML**: Google ML Kit (Face Detection), TFLite (MobileFaceNet)
- **Automation**: GitHub Actions (Node.js Watcher)
- **Animations**: Flutter Animate

---

## 🚀 Setup & Installation

### 1. Prerequisites
- Flutter SDK (latest version)
- Java JDK 17
- Firebase CLI (`npm install -g firebase-tools`)

### 2. Basic Configuration
- Download `google-services.json` from Firebase and place it in `android/app/`.
- Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
- Initialize Firebase options: `flutterfire configure`.

### 3. Automated Notifications (GitHub Action)
- Go to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions**.
- Create a secret named `FIREBASE_SERVICE_ACCOUNT`.
- Paste the entire content of your Firebase Service Account JSON key.

### 4. Database Security
Deploy the production rules to lock down the database:
```powershell
firebase deploy --only firestore:rules
```

---

## 📦 Production Deployment

### Android Release
To generate a secure, obfuscated, and signed APK:
1. Ensure your `android/key.properties` and `.jks` file are correctly configured.
2. Run the hardening command:
```powershell
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

---

## 📂 Project Structure

- `lib/models/`: Data structures (User, Leave, Complaint).
- `lib/services/`: Firebase, Face Recognition, and Notification logic.
- `lib/screens/`: UI for Auth, Student, and Warden Dashboards.
- `scripts/`: Node.js watcher for automated background tasks.
- `.github/workflows/`: Automated scheduling for notifications.

---

## 📄 License

This project is developed for **VISTA Hostel Management**. All rights reserved.
