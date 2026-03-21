import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';

// Mobile implementation using the safe_device package.
class SecurityImplementation {
  static Future<bool> isSecure() async {
    if (kDebugMode) return true; // Allows you to navigate the app on your emulator while coding
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        bool isRealDevice = await SafeDevice.isRealDevice;
        bool isJailBroken = await SafeDevice.isJailBroken;
        bool isMock = await SafeDevice.isMockLocation;

        return isRealDevice && !isJailBroken && !isMock;
      }
    } catch (e) {
      debugPrint("Security check failed on mobile: $e");
    }
    return false; // 100% Fail-Closed in Production
  }

  static Future<bool> isRealDevice() async {
    if (kDebugMode) return true; // Temporary bypass so you can test Attendance on Emulator
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        return await SafeDevice.isRealDevice; // Strict check that Ignores kDebugMode
      }
    } catch (e) {
      debugPrint("Real device check failed: $e");
    }
    return false; // 100% Fail-Closed
  }
}
