// Note: We use conditional exports/imports at the service level to be absolute safe.
// ignore: unused_import
import 'security_service_stub.dart' if (dart.library.io) 'security_service_mobile.dart';

class SecurityService {
  static Future<bool> checkSecurity() async {
    return await SecurityImplementation.isSecure();
  }

  static Future<bool> isRealDevice() async {
    return await SecurityImplementation.isRealDevice();
  }
}
