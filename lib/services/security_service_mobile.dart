import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';

// Mobile implementation using the safe_device package.
class SecurityImplementation {
  static Future<bool> isSecure() async {
    // if (kDebugMode) return true; // Removed per user request to block emulators even in debug
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        bool isRealDevice = await SafeDevice.isRealDevice;
        bool isJailBroken = await SafeDevice.isJailBroken;
        bool isMock = await SafeDevice.isMockLocation;
        bool isUsbDebugging = await SafeDevice.isUsbDebuggingEnabled;

        // Skip USB debugging check for testing purposes
        return isRealDevice && !isJailBroken && !isMock && !isUsbDebugging;
      }
    } catch (e) {
      debugPrint("Security check failed on mobile: $e");
    }
    return false; // 100% Fail-Closed in Production
  }

  static Future<bool> isRealDevice() async {
    // if (kDebugMode) return true; // Removed per user request
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
