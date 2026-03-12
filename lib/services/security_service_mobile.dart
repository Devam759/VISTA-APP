import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';

// Mobile implementation using the safe_device package.
class SecurityImplementation {
  static Future<bool> isSecure() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        bool isRealDevice = await SafeDevice.isRealDevice;
        bool isJailBroken = await SafeDevice.isJailBroken;
        bool isMock = await SafeDevice.isMockLocation;
        bool isDevMode = await SafeDevice.isDevelopmentModeEnable;

        return isRealDevice && !isJailBroken && !isMock && !isDevMode;
      }
    } catch (e) {
      debugPrint("Security check failed on mobile: $e");
    }
    return true; // Default to secure if check fails
  }

  static Future<bool> isRealDevice() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        return await SafeDevice.isRealDevice;
      }
    } catch (e) {
      debugPrint("Real device check failed: $e");
    }
    return true; // Default to true if check fails
  }
}
