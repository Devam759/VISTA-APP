# VISTA - Virtual Intelligent Student Tracking & Attendance

VISTA is a secure, automated university hostel management system developed with Flutter. The platform facilitates campus living by centralizing student registrations, leave permission workflows, grievance management, and attendance verification through advanced biometric integration and real-time cloud services.

## Recent Major Improvements (v1.3.1)

- **Automated Data Maintenance**: Implemented a 90-day lifecycle policy for Firebase Storage and a daily scheduled Cloud Function (`cleanupOldComplaintImages`) to automatically purge stale image references from Firestore.
- **Master Warden Filtering**: Head and Chief Wardens now have a unified "Master View" with dynamic hostel filtering across all dashboard tabs.
- **Premium Media Experience**: Enhanced the Complaint Attachment viewer with an aspect-ratio-preserving `BoxFit.contain` presentation, dark-slate background, and interactive zooming.
- **UI Animation Stabilization**: Refactored dashboard headers and entrance animations to be static during filter updates, preventing redundant UI "reveals" and ensuring a stable, professional feel.
- **Reactive State Management**: Implementation of `WardenProvider` to manage global data streams, ensuring real-time UI synchronization when filters change.
- **Enterprise Security**: Integration of **Firebase App Check**.

## Core Functionality

### Role-Based Access Control
- **Student Portal**: Enables students to apply for hostel membership, submit leave requests, and report complaints.
- **Warden Portal**: Administrative oversight for specific hostel blocks. Wardens review student applications and manage daily operations.
- **Head/Chief Warden**: Advanced administrative governance with the ability to filter and monitor data across **all hostels** (BH1, BH2, GH1, GH2) in a single unified view.
- **Approval Logic**: Mandatory verification by Wardens before active system participation.

### Biometric Attendance System
- **Face Recognition**: Integrates MobileFaceNet via TFLite for high-precision identity verification.
- **Liveness Verification**: Anti-spoofing mechanism requiring active Blink Detection.
- **Data Security**: Production-grade Firestore Security Rules ensure biometric data is only accessible to authorized administrative accounts.

### Automated Notification System
- **Cloud Functions**: Serverless Node.js backend (v1) for event-driven automation.
- **Real-Time Alerts**: High-priority Firebase Cloud Messaging (FCM) delivery for:
  - Registration approvals and status updates.
  - Leave and complaint resolution milestones.
  - **Night Attendance Reminder**: Dispatched daily at **10:00 PM IST**.

### Automated Lifecycle Management
To ensure storage efficiency and database hygiene:
- **Storage Purge**: Files in the `complaints/` storage path are automatically deleted after **90 days** via a GCP Storage Lifecycle rule.
- **Firestore Sync**: A scheduled Cloud Function runs daily at **2:00 AM IST** to nullify `imageUrl` fields for complaint documents older than 90 days, maintaining consistency between the database and physical storage.

## Technology Stack

- **Frontend**: Flutter (Dart) - MVVM architecture with **Provider** state management.
- **Backend**: Firebase (Auth, Firestore, Functions, Messaging, Storage, App Check).
- **AI/ML**: Google ML Kit (Face Detection) and TensorFlow Lite (Custom Inference).
- **Region**: Strategic deployment on `asia-south1` (Mumbai) for optimal performance.

## Installation and Configuration

### Prerequisites
- Flutter SDK (Stable)
- Java Development Kit (JDK) 17
- Firebase CLI (`npm install -g firebase-tools`)

### Initial Setup
1. **Firebase Integration**: 
   - Place `google-services.json` in `android/app/` and `GoogleService-Info.plist` in `ios/Runner/`.
   - Run `flutterfire configure` to generate `lib/firebase_options.dart`.
2. **Environment Configuration**:
   - Create a `.env` file in the root directory for sensitive environment variables.
3. **Cloud Functions**:
   ```bash
   cd functions && npm install
   ```
4. **Database Rules**:
   ```bash
   firebase deploy --only firestore:rules,storage:rules
   ```

## Production Deployment

### Optimized Build (v1.3.0+)
To generate a secure, obfuscated release build:
```powershell
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

## Directory Structure
- `lib/models/`: Data schemas and serialization logic.
- `lib/providers/`: Global state management and reactive data streams.
- `lib/services/`: Firebase, Biometrics, and Security implementation.
- `lib/screens/warden/tabs/`: Context-aware dashboard modules.
- `functions/`: Serverless backend automation.

## Licensing
Developed exclusively for the VISTA Hostel Management System. All rights reserved.
