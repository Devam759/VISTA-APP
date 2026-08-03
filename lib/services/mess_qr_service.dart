import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class MessQrResult {
  final bool isValid;
  final String? uid;
  final String? rollNo;
  final int? timestamp;
  final String? failureReason;

  MessQrResult({
    required this.isValid,
    this.uid,
    this.rollNo,
    this.timestamp,
    this.failureReason,
  });

  factory MessQrResult.success({required String uid, required String rollNo, required int timestamp}) {
    return MessQrResult(
      isValid: true,
      uid: uid,
      rollNo: rollNo,
      timestamp: timestamp,
    );
  }

  factory MessQrResult.fail(String reason) {
    return MessQrResult(
      isValid: false,
      failureReason: reason,
    );
  }
}

class MessQrService {
  // Secret key used for AES-256-CBC payload encryption & HMAC-SHA256 signature verification
  static const String _secretSeed = "VISTA_MESS_SECRET_KEY_2026_JKLU_SECURE_QR_ENGINE";

  static enc.Key _getAesKey() {
    final bytes = utf8.encode(_secretSeed);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  static String _generateNonce() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Generates a cryptographically signed and AES-256-CBC encrypted payload with 30-second TTL.
  static String generateSecureQrPayload(String uid, String rollNo) {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final expMs = nowMs + 30000; // 30 seconds expiration
      final nonce = _generateNonce();

      final key = _getAesKey();
      final iv = enc.IV.fromLength(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final rawPayloadData = jsonEncode({
        'u': uid,
        'r': rollNo,
        't': nowMs,
        'e': expMs,
        'n': nonce,
      });

      final encrypted = encrypter.encrypt(rawPayloadData, iv: iv);

      // Compute HMAC-SHA256 signature over encrypted payload + iv
      final hmac = Hmac(sha256, utf8.encode(_secretSeed));
      final sigData = "${iv.base64}.${encrypted.base64}";
      final digest = hmac.convert(utf8.encode(sigData));

      final finalPayload = jsonEncode({
        'iv': iv.base64,
        'data': encrypted.base64,
        'sig': digest.toString(),
      });

      return base64Url.encode(utf8.encode(finalPayload));
    } catch (e) {
      return '';
    }
  }

  /// Validates the QR payload: decodes payload, verifies HMAC signature, checks 30s expiration & tampering.
  static MessQrResult validateQrPayload(String rawString) {
    if (rawString.isEmpty) {
      return MessQrResult.fail("Empty QR code payload");
    }

    try {
      final decodedJsonStr = utf8.decode(base64Url.decode(rawString));
      final Map<String, dynamic> container = jsonDecode(decodedJsonStr);

      final ivBase64 = container['iv']?.toString();
      final dataBase64 = container['data']?.toString();
      final sig = container['sig']?.toString();

      if (ivBase64 == null || dataBase64 == null || sig == null) {
        return MessQrResult.fail("Invalid QR payload structure");
      }

      // Verify HMAC-SHA256 digital signature
      final hmac = Hmac(sha256, utf8.encode(_secretSeed));
      final sigData = "$ivBase64.$dataBase64";
      final computedSig = hmac.convert(utf8.encode(sigData)).toString();

      if (computedSig != sig) {
        return MessQrResult.fail("Cryptographic signature check failed (Tampered QR)");
      }

      // Decrypt AES payload
      final key = _getAesKey();
      final iv = enc.IV.fromBase64(ivBase64);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decryptedText = encrypter.decrypt(enc.Encrypted.fromBase64(dataBase64), iv: iv);

      final Map<String, dynamic> data = jsonDecode(decryptedText);
      final uid = data['u']?.toString();
      final rollNo = data['r']?.toString();
      final ts = data['t'] is int ? data['t'] as int : 0;
      final exp = data['e'] is int ? data['e'] as int : 0;

      if (uid == null || rollNo == null || exp == 0) {
        return MessQrResult.fail("Invalid or corrupted payload content");
      }

      // Check Expiration (30 seconds TTL + 15s grace for clock skew)
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs > exp + 15000) {
        return MessQrResult.fail("Expired QR code. Please refresh student screen.");
      }

      return MessQrResult.success(uid: uid, rollNo: rollNo, timestamp: ts);
    } catch (e) {
      return MessQrResult.fail("QR Decryption / Parsing failure");
    }
  }
}
