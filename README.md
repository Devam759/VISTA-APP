# VISTA - Virtual Intelligent Student Tracking & Attendance

VISTA is a secure, automated university hostel management system developed with Flutter. The platform facilitates campus living by centralizing student registrations, leave permission workflows, grievance management, and attendance verification through advanced biometric integration and real-time cloud services.

## Core Functionality

### Role-Based Access Control
- **Student Portal**: Enables students to apply for hostel membership, submit leave requests, and report complaints.
- **Warden Portal**: Provides administrative oversight for specific hostel blocks (BH1, BH2, GH1, GH2). Wardens review student applications and manage daily operations.
- **Head Warden/Chief Warden**: Offers high-level administrative governance, including escalated complaint resolution and system-wide monitoring.

### Biometric Attendance System
- **Face Recognition**: Integrates MobileFaceNet via TFLite for high-precision identity verification.
- **Liveness Verification**: Incorporates an anti-spoofing mechanism requiring active Blink Detection to ensure physical presence.
- **Data Security**: Biometric data is strictly protected using production-grade Firestore Security Rules, ensuring privacy and compliance.

### Automated Notification System
- **Monitoring Service**: A background service (Node.js) monitors database changes via GitHub Actions.
- **Real-Time Alerts**: Utilizes Firebase Cloud Messaging (FCM) to deliver push notifications for critical events, including:
  - Registration approvals and status updates.
  - Leave and complaint resolution milestones.
  - Nightly attendance reminders (scheduled for 10:00 PM and 10:20 PM IST).

### System Security
- **Data Privacy**: Role-Based Access Control (RBAC) is enforced at the database level to protect sensitive student records.
- **Application Hardening**: Release builds utilize Dart code obfuscation to prevent reverse-engineering.
- **Integrity**: Standardized keystore management ensures the authenticity of production binaries.

## Technology Stack

- **Frontend**: Flutter (Dart) using MVVM architecture and Provider state management.
- **Backend**: Firebase suite (Authentication, Cloud Firestore, Cloud Messaging, Cloud Storage, App Check).
- **Artificial Intelligence**: Google ML Kit (Face Detection) and TensorFlow Lite (Inference Engine).
- **DevOps**: GitHub Actions for automated background services and Node.js for specialized monitoring scripts.

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
2. **Automated Tasks (GitHub Actions)**:
   - Configure a `FIREBASE_SERVICE_ACCOUNT` secret in the GitHub repository settings.
   - Populate this secret with the JSON key from the Firebase Service Account.
3. **Database Security**:
   Deploy the defined security rules:
   ```powershell
   firebase deploy --only firestore:rules
   ```

## Production Deployment

### Android Release
To generate an optimized and secure production build, execute the following command:
```powershell
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```
*Note: Ensure that `android/key.properties` and the associated keystore are correctly configured before building.*

## Directory Structure

- `lib/models/`: Implementation of data schemas for users, leave requests, and complaints.
- `lib/services/`: Core logic for Firebase integration, biometric processing, and notification handling.
- `lib/screens/`: User interface components for authentication and role-specific dashboards.
- `scripts/`: Node.js implementation for backend synchronization tasks.
- `.github/workflows/`: Configuration for automated notification scheduling.

## Licensing

Developed exclusively for the VISTA Hostel Management System. All rights reserved.

