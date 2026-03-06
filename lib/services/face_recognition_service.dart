import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Pure-Dart face recognition using ML Kit face-contour landmarks.
/// No TFLite / FFI required — works on Android, iOS and Web builds.
///
/// Strategy:
///   • Extract the 36 face-oval contour points from a detected [Face].
///   • Normalise them relative to the face bounding-box so they are
///     invariant to position and scale.
///   • Store the resulting vector (72 floats) in Firestore.
///   • On verification compute RMSE between stored and live vectors;
///     RMSE < 0.12 → same person.
class FaceRecognitionService {
  static const double _matchThreshold = 0.70; // similarity score 0–1

  /// Extracts a normalised landmark vector from [face].
  /// Throws if no face-oval contour is available.
  List<double> extractLandmarks(Face face) {
    final contour = face.contours[FaceContourType.face];
    if (contour == null || contour.points.isEmpty) {
      throw Exception(
        'No face contour detected. Ensure the face is fully visible.',
      );
    }

    final box = face.boundingBox;
    final centerX = box.left + box.width / 2;
    final centerY = box.top + box.height / 2;
    final scale = (box.width + box.height) / 2; // mean dimension

    final result = <double>[];
    for (final p in contour.points) {
      result.add((p.x - centerX) / scale);
      result.add((p.y - centerY) / scale);
    }
    return result;
  }

  /// Cosine-similarity-like score between [a] and [b] based on RMSE.
  /// Returns 1.0 for identical vectors, 0.0 for completely different.
  static double similarity(List<double> a, List<double> b) {
    final len = min(a.length, b.length);
    if (len == 0) return 0;
    double sumSq = 0;
    for (int i = 0; i < len; i++) {
      final d = a[i] - b[i];
      sumSq += d * d;
    }
    final rmse = sqrt(sumSq / len);
    // Map RMSE to [0,1]: rmse=0 → score=1, rmse≥0.30 → score=0
    return (1.0 - rmse / 0.30).clamp(0.0, 1.0);
  }

  /// Returns true when [candidate] landmarks are similar enough to [stored]
  /// to be considered the same person.
  static bool isMatch(List<double> stored, List<double> candidate) {
    return similarity(stored, candidate) >= _matchThreshold;
  }
}
