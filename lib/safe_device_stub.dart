// Stub for safe_device package on web.
// The real safe_device package uses native channels not available on web.
// All usages are already guarded with !kIsWeb, this stub just satisfies the import.

class SafeDevice {
  static Future<bool> get isRealDevice async => true;
  static Future<bool> get isJailBroken async => false;
  static Future<bool> get isMockLocation async => false;
  static Future<bool> get isDevelopmentModeEnable async => false;
}
