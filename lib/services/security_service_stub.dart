// Stub implementation for web and platforms where safe_device is not supported.
class SecurityImplementation {
  static Future<bool> isSecure() async {
    // Web is always considered secure for our purposes as safe_device check doesn't apply.
    return true;
  }

  static Future<bool> isRealDevice() async {
    return true;
  }
}
