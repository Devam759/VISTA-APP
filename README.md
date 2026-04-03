# VISTA - Virtual Intelligent Student Tracking & Attendance

VISTA is a secure, automated university hostel management system developed with Flutter. The platform facilitates campus living by centralizing student registrations, leave permission workflows, grievance management, and attendance verification through advanced biometric integration and real-time cloud services.

## Core Functionality

### Role-Based Access Control
- **Student Portal**: Enables students to apply for hostel membership, submit leave requests, and report complaints.
- **Warden Portal**: Provides administrative oversight for specific hostel blocks (BH1, BH2, GH1, GH2). Wardens review student applications and manage daily operations.
- **Head Warden/Chief Warden**: Offers high-level administrative governance, including escalated complaint resolution and system-wide monitoring.
- **Approval Logic**: Strict enforcement of Warden approval for hostellers. New students are held in a **Pending Approval** state until verified by their respective warden.

### Biometric Attendance System
- **Face Recognition**: Integrates MobileFaceNet via TFLite for high-precision identity verification.
- **Liveness Verification**: Incorporates an anti-spoofing mechanism requiring active Blink Detection to ensure physical presence.
- **Data Security**: Biometric data is strictly protected using production-grade Firestore Security Rules, ensuring privacy and compliance.

### Automated Notification System
- **Cloud Functions**: A serverless backend (Firebase Functions v1) monitors database changes and manages scheduled tasks.
- **Real-Time & Scheduled Alerts**: Utilizes Firebase Cloud Messaging (FCM) to deliver push notifications, including:
  - Registration approvals and status updates.
  - Leave and complaint resolution milestones.
  - **Night Attendance Reminder**: Scheduled for exactly **10:00 PM IST** daily.
  - **Reliability**: Notifications use **High Priority** delivery to bypass device battery optimizations (Doze mode) on Android and iOS.

### Authentication & Integration
- **Microsoft SSO**: Integrated Microsoft sign-in for university accounts, with mandatory `intent-filter` configuration in `AndroidManifest.xml` for seamless OAuth redirects.
- **Identity Anchoring**: Phone number uniqueness is enforced to prevent account duplication.

## Technology Stack

- **Frontend**: Flutter (Dart) using MVVM architecture and Provider state management.
- **Backend**: Firebase suite (Authentication, Cloud Firestore, Cloud Functions, Cloud Messaging, Cloud Storage, App Check).
- **Artificial Intelligence**: Google ML Kit (Face Detection) and TensorFlow Lite (Inference Engine).
- **Region**: Optimized for `asia-south1` (Mumbai) to minimize latency for users in India.

## Installation and Configuration

### Prerequisites
- Flutter SDK (Stable channel)
- Java Development Kit (JDK) 17
- Firebase CLI (`npm install -g firebase-tools`)

### Initial Setup
1. **Firebase Integration**:
   - Place `google-services.json` in `android/app/`.
   - Place `GoogleService-Info.plist` in `ios/Runner/`.
   - Run `flutterfire configure` to synchronize environment settings.
2. **Cloud Functions**:
   Navigate to the `functions/` directory and install dependencies:
   ```bash
   npm install
   ```
3. **Database Security**:
   Deploy the defined security rules:
   ```powershell
   firebase deploy --only firestore:rules
   ```

## Production Deployment

### Android Release
To generate an optimized and secure production build (Current Version: `1.2.5+8`), execute:
```powershell
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```
*Note: Ensure that `android/key.properties` and the associated keystore are correctly configured.*

## Directory Structure

- `lib/models/`: Implementation of data schemas for users, leave requests, and complaints.
- `lib/services/`: Core logic for Firebase integration, biometric processing, and notification handling.
- `lib/screens/`: User interface components for authentication and role-specific dashboards.
- `functions/`: Cloud Functions implementation in Node.js for backend automation.

## Licensing

Developed exclusively for the VISTA Hostel Management System. All rights reserved.

