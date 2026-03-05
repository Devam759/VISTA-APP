# VISTA - Hostel Management System

VISTA is a Flutter-based mobile application designed for efficient university hostel management using Firebase as a backend.

## Features

- **Role-Based Access**: Student, Warden, and Head Warden.
- **JKLU Email Integration**: Only official email addresses can register.
- **Night Attendance**: Daily attendance between 10:00 PM and 10:30 PM.
- **Leave Requests**: Student applies, Warden approves/rejects.
- **Anonymous Complaints**: Students submit feedback; escalated to Head Warden if not resolved.
- **Room Assignment**: Wardens assign room numbers upon student approval.

## Setup Instructions

1.  **Firebase Project**:
    - Create a new project in [Firebase Console](https://console.firebase.google.com/).
    - Enable **Email/Password Authentication**.
    - Create a **Cloud Firestore** database.
    - Enable **Cloud Messenger (FCM)** for notifications.
2.  **Configuration Files**:
    - Build for Android: Download `google-services.json` and place it in `android/app/`.
    - Build for iOS: Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
3.  **Warden Accounts**:
    - Manually create 4 Warden accounts in Firestore `users` collection with:
      - `role`: 'warden'
      - `hostel`: 'BH1', 'BH2', 'GH1', 'GH2'
      - `isApproved`: true
4.  **Head Warden Account**:
    - Create 1 account with `role`: 'headWarden' and `isApproved`: true.

## Tech Stack

- **Frontend**: Flutter
- **Backend**: Firebase Authentication, Firestore, Cloud Messaging, Storage.
- **Architecture**: MVVM with Provider.
