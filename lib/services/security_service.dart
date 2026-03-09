// Note: We use conditional exports/imports at the service level to be absolute safe.
// ignore: unused_import
import 'security_service_stub.dart' if (dart.library.io) 'security_service_mobile.dart';

class SecurityService {
  static Future<bool> checkSecurity() async {
    return await SecurityImplementation.isSecure();
  }
}

// Internal implementation that will be swapped by the compiler.
abstract class SecurityImplementation {
  static Future<bool> isSecure() async => true;
}
