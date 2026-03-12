# Getting Started

<cite>
**Referenced Files in This Document**
- [README.md](file://README.md)
- [pubspec.yaml](file://pubspec.yaml)
- [lib/firebase_options.dart](file://lib/firebase_options.dart)
- [android/app/google-services.json](file://android/app/google-services.json)
- [ios/Runner/GoogleService-Info.plist](file://ios/Runner/GoogleService-Info.plist)
- [firebase.json](file://firebase.json)
- [.github/workflows/notify_watcher.yml](file://.github/workflows/notify_watcher.yml)
- [.github/workflows/attendance_reminders.yml](file://.github/workflows/attendance_reminders.yml)
- [scripts/notify_watcher.js](file://scripts/notify_watcher.js)
- [scripts/send_reminders.js](file://scripts/send_reminders.js)
- [web/firebase-messaging-sw.js](file://web/firebase-messaging-sw.js)
- [android/build.gradle.kts](file://android/build.gradle.kts)
- [android/gradle.properties](file://android/gradle.properties)
- [android/local.properties](file://android/local.properties)
- [ios/Podfile](file://ios/Podfile)
- [linux/CMakeLists.txt](file://linux/CMakeLists.txt)
- [windows/CMakeLists.txt](file://windows/CMakeLists.txt)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Environment Setup](#environment-setup)
4. [Firebase Project Setup](#firebase-project-setup)
5. [Configure Firebase Options](#configure-firebase-options)
6. [Platform-Specific Setup](#platform-specific-setup)
7. [Automated Notification System](#automated-notification-system)
8. [First-Time Developer Checklist](#first-time-developer-checklist)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Next Steps](#next-steps)

## Introduction
This guide helps you set up the VISTA APP development environment from scratch. It covers prerequisites, Firebase configuration, platform setup for Android, iOS, Web, and Desktop, and the automated notification system powered by GitHub Actions. Follow the steps below to ensure a smooth developer experience.

## Prerequisites
Before starting, ensure you have:
- Flutter SDK installed and working
- Java JDK 17 (required for Android builds)
- Firebase CLI installed globally (`npm install -g firebase-tools`)

These requirements are documented in the project’s setup instructions.

**Section sources**
- [README.md:47-50](file://README.md#L47-L50)

## Environment Setup
Set up your development machine with the required tools:
- Install Flutter SDK according to your OS
- Install Java JDK 17 and configure your environment to use it
- Install Firebase CLI globally

Tip: Verify installations by running flutter doctor and checking Java and Firebase CLI versions.

**Section sources**
- [README.md:47-50](file://README.md#L47-L50)

## Firebase Project Setup
VISTA APP uses Firebase for authentication, Firestore, Cloud Messaging, and hosting. The project expects:
- A Firebase project named “vista-jklu”
- Android app registered with package name matching the Android configuration
- iOS app registered with bundle ID matching the iOS configuration
- Web app configured for hosting

Project configuration references:
- Firebase project ID and app IDs are defined in the FlutterFire configuration and platform JSON files.
- Hosting public directory and rewrite rules are defined in the Firebase configuration.

Key configuration files:
- Android configuration JSON
- iOS configuration Plist
- FlutterFire configuration mapping
- Firebase hosting and functions configuration

**Section sources**
- [lib/firebase_options.dart:49-74](file://lib/firebase_options.dart#L49-L74)
- [android/app/google-services.json:1-29](file://android/app/google-services.json#L1-L29)
- [ios/Runner/GoogleService-Info.plist:1-30](file://ios/Runner/GoogleService-Info.plist#L1-L30)
- [firebase.json:22-40](file://firebase.json#L22-L40)

## Configure Firebase Options
After creating your Firebase project and registering Android/iOS/Web apps, download the appropriate configuration files and initialize Firebase options in your Flutter app.

Steps:
1. Download google-services.json from Firebase Console and place it in android/app/
2. Download GoogleService-Info.plist from Firebase Console and place it in ios/Runner/
3. Initialize Firebase options using the FlutterFire CLI

Initialization command:
- flutterfire configure

This creates or updates the FlutterFire options file used by the app to initialize Firebase per platform.

**Section sources**
- [README.md:52-55](file://README.md#L52-L55)
- [lib/firebase_options.dart:17-47](file://lib/firebase_options.dart#L17-L47)
- [firebase.json:2-21](file://firebase.json#L2-L21)

## Platform-Specific Setup

### Android
- Place google-services.json in android/app/
- Ensure Gradle and local properties are configured
- Confirm AndroidX is enabled and JVM arguments are set appropriately

Key files:
- Android Gradle configuration
- Gradle properties
- Local properties

**Section sources**
- [android/app/google-services.json:1-29](file://android/app/google-services.json#L1-L29)
- [android/build.gradle.kts:1-25](file://android/build.gradle.kts#L1-L25)
- [android/gradle.properties:1-6](file://android/gradle.properties#L1-L6)
- [android/local.properties:1-5](file://android/local.properties#L1-L5)

### iOS
- Place GoogleService-Info.plist in ios/Runner/
- Ensure the iOS deployment target and permissions are configured in the Podfile
- Build and run using Xcode or Flutter CLI

Key files:
- iOS Podfile
- iOS configuration plist

**Section sources**
- [ios/Runner/GoogleService-Info.plist:1-30](file://ios/Runner/GoogleService-Info.plist#L1-L30)
- [ios/Podfile:1-72](file://ios/Podfile#L1-L72)

### Web
- Firebase Hosting is configured to serve build/web
- Background FCM service worker is included in web/

Key files:
- Firebase Hosting configuration
- Web FCM service worker

**Section sources**
- [firebase.json:27-40](file://firebase.json#L27-L40)
- [web/firebase-messaging-sw.js:1-26](file://web/firebase-messaging-sw.js#L1-L26)

### Desktop (Linux, macOS, Windows)
- Flutter desktop build files are provided for each platform
- Ensure Flutter desktop support is enabled and dependencies are met

Key files:
- Linux CMake configuration
- Windows CMake configuration

Note: macOS configuration exists under macos/Runner/Configs and related files.

**Section sources**
- [linux/CMakeLists.txt:1-129](file://linux/CMakeLists.txt#L1-L129)
- [windows/CMakeLists.txt:1-109](file://windows/CMakeLists.txt#L1-L109)

## Automated Notification System
VISTA APP includes two GitHub Actions workflows that automate notifications:
- Real-time Notifications Watcher: Runs every 10 minutes to check Firestore and send push notifications
- Attendance Reminders: Sends scheduled reminders at 10:00 PM and 10:20 PM IST

Setup:
- Create a GitHub Actions Secret named FIREBASE_SERVICE_ACCOUNT containing your Firebase Admin Service Account JSON
- Workflows are defined in .github/workflows/ and reference Node.js scripts in scripts/

Workflow files:
- Real-time watcher
- Attendance reminders

Node.js scripts:
- Watcher script
- Reminders script

**Section sources**
- [README.md:57-61](file://README.md#L57-L61)
- [.github/workflows/notify_watcher.yml:1-29](file://.github/workflows/notify_watcher.yml#L1-L29)
- [.github/workflows/attendance_reminders.yml:1-46](file://.github/workflows/attendance_reminders.yml#L1-L46)
- [scripts/notify_watcher.js:1-165](file://scripts/notify_watcher.js#L1-L165)
- [scripts/send_reminders.js:1-210](file://scripts/send_reminders.js#L1-L210)

## First-Time Developer Checklist
- Install Flutter SDK and verify with flutter doctor
- Install Java JDK 17 and confirm Gradle uses the correct JDK
- Install Firebase CLI globally
- Create a Firebase project named “vista-jklu” and register Android/iOS/Web apps
- Download and place google-services.json and GoogleService-Info.plist
- Initialize Firebase options with flutterfire configure
- For desktop, ensure Flutter desktop support is enabled
- For GitHub Actions, add FIREBASE_SERVICE_ACCOUNT secret and review workflow schedules

**Section sources**
- [README.md:47-61](file://README.md#L47-L61)
- [pubspec.yaml:30-70](file://pubspec.yaml#L30-L70)

## Troubleshooting Guide
Common issues and resolutions:
- Android build fails due to JDK mismatch
  - Ensure Gradle uses JDK 17. Adjust org.gradle.java.home or JAVA_HOME accordingly.
  - Verify Android SDK path in local.properties.
- iOS build issues
  - Confirm iOS deployment target and permissions in Podfile.
  - Re-run pod install after Flutter upgrades.
- Firebase initialization errors
  - Verify google-services.json and GoogleService-Info.plist are placed in the correct directories.
  - Re-run flutterfire configure to regenerate options.
- GitHub Actions failures
  - Confirm FIREBASE_SERVICE_ACCOUNT secret is set in repository Settings > Secrets and variables > Actions.
  - Check workflow logs for Node.js version compatibility and dependency installation.

**Section sources**
- [android/gradle.properties:4-5](file://android/gradle.properties#L4-L5)
- [android/local.properties:1-5](file://android/local.properties#L1-L5)
- [ios/Podfile:52-63](file://ios/Podfile#L52-L63)
- [README.md:57-61](file://README.md#L57-L61)

## Next Steps
- Run the app locally on Android, iOS, Web, or Desktop using flutter run
- Test Firebase connectivity and Cloud Messaging
- Trigger GitHub Actions manually to validate notification flows
- Review and customize Firestore rules and indexes as needed

**Section sources**
- [README.md:45-95](file://README.md#L45-L95)
- [firebase.json:22-54](file://firebase.json#L22-L54)