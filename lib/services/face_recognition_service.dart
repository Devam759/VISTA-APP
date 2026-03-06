import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// Face recognition using MobileFaceNet TFLite model.
/// Accuracy is significantly higher than landmark-based comparison.
class FaceRecognitionService {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  FaceRecognitionService() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/facenet.tflite',
      );
      _isModelLoaded = true;
      print('MobileFaceNet model loaded successfully.');
    } catch (e) {
      print('Failed to load MobileFaceNet model: $e');
    }
  }

  /// Generates a 192-dimensional embedding from a cropped face image.
  Future<List<double>> getEmbedding(img.Image faceImage) async {
    if (!_isModelLoaded) await _loadModel();
    if (_interpreter == null) throw Exception('Model not loaded');

    // 1. Fix orientation (Android photos often rotated)
    final oriented = img.bakeOrientation(faceImage);

    // 2. Resize to 112x112 (Standard for MobileFaceNet)
    final resized = img.copyResize(oriented, width: 112, height: 112);

    // 3. Pre-process: Normalise pixels to [-1, 1]
    final input = Float32List(1 * 112 * 112 * 3);
    var pixelIndex = 0;
    for (final pixel in resized) {
      input[pixelIndex++] = (pixel.r - 127.5) / 127.5;
      input[pixelIndex++] = (pixel.g - 127.5) / 127.5;
      input[pixelIndex++] = (pixel.b - 127.5) / 127.5;
    }

    // 4. Run Inference (Dynamic output shape to support 128, 192, 512, etc.)
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final outputSize = outputShape.reduce((a, b) => a * b);
    var output = List.filled(outputSize, 0.0).reshape(outputShape);

    _interpreter!.run(input.reshape([1, 112, 112, 3]), output);

    // Flatten to a List<double>
    if (outputShape.length == 2) {
      return List<double>.from(output[0]);
    }
    return List<double>.from(output);
  }

  /// Computes cosine similarity between two 192-dim vectors.
  /// 1.0 = identical, -1.0 = opposite.
  static double similarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    double dotProduct = 0;
    double normA = 0;
    double normB = 0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  static bool isMatch(List<double> stored, List<double> candidate) {
    final score = similarity(stored, candidate);
    // Threshold for MobileFaceNet is typically around 0.6 to 0.7 for cosine
    return score >= 0.65;
  }

  // Legacy compatibility for code that still expects landmark extraction
  // (We should update FaceCaptureScreen to use getEmbedding with an image)
  List<double> extractLandmarks(dynamic _) => [];
}
