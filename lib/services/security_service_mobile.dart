import 'package:device_info_plus/device_info_plus.dart';
import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';

/// Mobile security implementation using safe_device and device_info_plus.
/// Protects VISTA against BlueStacks, PC Android Emulators, Rooted devices, and Mock GPS.
class SecurityImplementation {
  // Set to false for 100% production security enforcement.
  // Set to true only during local USB debugging & development.
  static const bool disableSecurityChecksForTesting = false;

  static Future<bool> isSecure() async {
    if (disableSecurityChecksForTesting) return true;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // 1. Hardware Fingerprint Check (Blocks BlueStacks, Nox, MEmu, Genymotion, QEMU)
        final isEmulator = await _isBlueStacksOrEmulator();
        if (isEmulator) {
          debugPrint('SECURITY REJECTION: BlueStacks / Emulator hardware fingerprint detected.');
          return false;
        }

        // 2. SafeDevice Security Environment Checks
        bool isRealDevice = await SafeDevice.isRealDevice;
        bool isJailBroken = await SafeDevice.isJailBroken;
        bool isMock = await SafeDevice.isMockLocation;
        bool isUsbDebugging = await SafeDevice.isUsbDebuggingEnabled;
        bool isDevMode = await SafeDevice.isDevelopmentModeEnable;

        return isRealDevice && !isJailBroken && !isMock && !isUsbDebugging && !isDevMode;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        bool isRealDevice = await SafeDevice.isRealDevice;
        bool isJailBroken = await SafeDevice.isJailBroken;
        bool isMock = await SafeDevice.isMockLocation;
        return isRealDevice && !isJailBroken && !isMock;
      }
    } catch (e) {
      debugPrint("Security check error on mobile: $e");
    }
    return false; // Fail-Closed
  }

  /// Explicit hardware signature analysis for BlueStacks, Nox, MEmu, and PC Emulators
  static Future<bool> _isBlueStacksOrEmulator() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final android = await deviceInfo.androidInfo;

      if (!android.isPhysicalDevice) return true;

      final hardware = android.hardware.toLowerCase();
      final board = android.board.toLowerCase();
      final model = android.model.toLowerCase();
      final fingerprint = android.fingerprint.toLowerCase();
      final manufacturer = android.manufacturer.toLowerCase();
      final product = android.product.toLowerCase();

      final emulatorKeywords = [
        'bluestacks',
        'vbox86',
        'goldfish',
        'ranchu',
        'nox',
        'ttvm',
        'genymotion',
        'androvm',
        'droid4x',
        'windroy',
        'memu',
        'sdk_gphone',
        'google_sdk',
        'emulator',
      ];

      for (final keyword in emulatorKeywords) {
        if (hardware.contains(keyword) ||
            board.contains(keyword) ||
            model.contains(keyword) ||
            fingerprint.contains(keyword) ||
            manufacturer.contains(keyword) ||
            product.contains(keyword)) {
          return true;
        }
      }

      if (fingerprint.startsWith('generic') || fingerprint.startsWith('unknown')) {
        return true;
      }
    } catch (e) {
      debugPrint('Emulator signature check error: $e');
    }
    return false;
  }

  static Future<bool> isRealDevice() async {
    if (disableSecurityChecksForTesting) return true;
    final isEmulator = await _isBlueStacksOrEmulator();
    if (isEmulator) return false;
    return await SafeDevice.isRealDevice;
  }
}
