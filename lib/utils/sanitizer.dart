import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Centralized utility for user input sanitization.
/// Provides multi-layered protection against XSS, NoSQL/SQL injection,
/// and suspicious pattern detection using heuristic analysis.
class InputSanitizer {
  // Regex for HTML tags (XSS)
  static final RegExp _htmlTagRegExp = RegExp(r'<[^>]*>', multiLine: true);

  // Regex for JavaScript events/patterns (XSS)
  static final RegExp _jsPatternRegExp = RegExp(
    r'(on[a-z]+|script|javascript|eval|expression|onerror|onload)\s*[:=]',
    caseSensitive: false,
    multiLine: true,
  );

  // Regex for NoSQL/SQL manipulation patterns
  static final RegExp _injectionRegExp = RegExp(
    r'(\$gt|\$ne|\$where|\$regex|OR\s+1=1|UNION\s+SELECT|--|\bDROP\b|\bDELETE\b)',
    caseSensitive: false,
  );

  /// Main sanitization entry point.
  /// Neutralizes common attacks and flags "high entropy" suspicious inputs.
  static String sanitize(String input, {bool allowParagraphs = true}) {
    if (input.isEmpty) return "";

    String sanitized = input;

    // 1. Strip HTML tags
    sanitized = sanitized.replaceAll(_htmlTagRegExp, '');

    // 2. Neutralize suspicious JS keywords (XSS)
    // We don't just delete them (to avoid breaking valid text like "script")
    // but we neutralize the dangerous part of the pattern.
    sanitized = sanitized.replaceAll(_jsPatternRegExp, '[redacted]');

    // 3. Neutralize NoSQL/SQL operators
    sanitized = sanitized.replaceAll(_injectionRegExp, '[secure]');

    // 4. Heuristic "AI" suspicious pattern detection
    if (_isSuspicious(sanitized)) {
      debugPrint("InputSanitizer: Flagging and sanitizing suspicious high-entropy input.");
      // If suspicious, we're even more aggressive with character stripping
      sanitized = sanitized.replaceAll(RegExp(r'[^\w\s.,?!-]'), '');
    }

    return sanitized.trim();
  }

  /// Heuristic scanner for "AI-like" detection of malicious payloads.
  /// Looks for high non-alpha character density or extremely high entropy strings.
  static bool _isSuspicious(String input) {
    if (input.length < 10) return false;

    // A: Check for high special character density (common in payloads/encoding)
    int specialCount = input.replaceAll(RegExp(r'[\w\s]'), '').length;
    double specialDensity = specialCount / input.length;
    if (specialDensity > 0.4 && input.length > 20) return true;

    // B: Shannon entropy-like check for base64 or obfuscated payloads
    double entropy = _calculateEntropy(input);
    if (entropy > 4.5 && input.length > 30) return true;

    return false;
  }

  /// Simple character-based entropy calculation
  static double _calculateEntropy(String input) {
    if (input.isEmpty) return 0;
    Map<String, int> frequencies = {};
    for (int i = 0; i < input.length; i++) {
        String char = input[i];
        frequencies[char] = (frequencies[char] ?? 0) + 1;
    }
    double entropy = 0;
    for (int count in frequencies.values) {
        double p = count / input.length;
        entropy -= p * (math.log(p) / math.ln2);
    }
    return entropy;
  }

  /// Normalizes phone numbers by stripping non-digit characters
  /// and handling common prefixes (e.g., +91).
  static String normalizePhone(String phone) {
    if (phone.isEmpty) return "";
    // Remove all non-digit characters
    String normalized = phone.replaceAll(RegExp(r'\D'), '');
    // If it's an Indian number with 91 prefix, strip it (12 digits total)
    if (normalized.length == 12 && normalized.startsWith('91')) {
      return normalized.substring(2);
    }
    // If it's a 10-digit number, return as is
    return normalized;
  }

  /// Formats phone number to +91 format for storage and display
  /// Input can be: 7340015201, 917340015201, +917340015201, 07340015201, etc.
  static String formatPhoneWithCountryCode(String phone) {
    if (phone.isEmpty) return "";
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    
    // Remove leading 0 if present
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    
    // If it already has 91 prefix, ensure it's valid
    if (digits.length == 12 && digits.startsWith('91')) {
      // Verify it's a valid Indian mobile (starts with 6, 7, 8, or 9)
      final mobilePrefix = digits.substring(2, 3);
      if (RegExp(r'[6-9]').hasMatch(mobilePrefix)) {
        return '+91 ${digits.substring(2)}';
      }
    }
    
    // If it's a 10-digit number, add +91
    if (digits.length == 10) {
      // Verify it's a valid Indian mobile (starts with 6, 7, 8, or 9)
      final mobilePrefix = digits.substring(0, 1);
      if (RegExp(r'[6-9]').hasMatch(mobilePrefix)) {
        return '+91 $digits';
      }
    }
    
    // Return original if we can't format it properly
    return phone;
  }

  /// Capitalizes the first letter of each word in a string.
  static String capitalize(String input) {
    if (input.isEmpty) return "";
    return input.split(' ').map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
