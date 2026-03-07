import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../../services/face_recognition_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODE
// ─────────────────────────────────────────────────────────────────────────────
enum FaceCaptureMode { registration, verification }

// ─────────────────────────────────────────────────────────────────────────────
// RESULT
// ─────────────────────────────────────────────────────────────────────────────
class FaceCaptureResult {
  final bool success;
  final String? message;
  const FaceCaptureResult({required this.success, this.message});
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class FaceCaptureScreen extends StatefulWidget {
  final String userId;
  final FaceCaptureMode mode;

  const FaceCaptureScreen({
    super.key,
    required this.userId,
    required this.mode,
  });

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _cam;
  CameraDescription? _cameraDescription;
  late FaceDetector _detector;
  final FaceRecognitionService _frs = FaceRecognitionService();

  String _statusMessage = '';
  bool _processing = false;
  bool _isProcessingFrame = false;

  // Liveness (Blink)
  int _blinkCount = 0;
  bool _eyesWereClosed = false;
  static const int _blinkTarget = 1;
  bool _livenessConfirmed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Face detector with contours (for landmark extraction) + classification (for blink)
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true, // face oval landmarks
        enableClassification: true, // eye-open probability → blink
        performanceMode:
            FaceDetectorMode.fast, // Fast is better for real-time blink
      ),
    );

    // Front camera
    final cameras = await availableCameras();
    _cameraDescription = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final front = _cameraDescription!;

    _cam = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
    ); // Medium is best for landmarks
    await _cam!.initialize();

    if (mounted) {
      setState(() {
        _statusMessage =
            'Align face & blink once to ${widget.mode == FaceCaptureMode.registration ? 'register' : 'verify'}.';
      });
      _cam!.startImageStream(_onFrame);
    }
  }

  void _onFrame(CameraImage image) async {
    if (_isProcessingFrame || _processing || _livenessConfirmed) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _getInputImage(image);
      if (inputImage == null) return;

      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          setState(() => _statusMessage = 'Searching for face…');
        }
        return;
      }

      final face = faces.first;

      // Blink detection
      final leftOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightOpen = face.rightEyeOpenProbability ?? 1.0;
      final eyesClosed = leftOpen < 0.3 && rightOpen < 0.3;

      if (eyesClosed && !_eyesWereClosed) {
        _eyesWereClosed = true;
      } else if (!eyesClosed && _eyesWereClosed) {
        _blinkCount++;
        _eyesWereClosed = false;
        debugPrint('Blink detected! Total: $_blinkCount');
      }

      if (_blinkCount >= _blinkTarget && !_livenessConfirmed) {
        _livenessConfirmed = true;
        debugPrint('Liveness confirmed. Processing face…');
        // Hands-free trigger!
        await _processDetectedFace(face);
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = eyesClosed
                ? 'Eyes Closed…'
                : 'Blinked: $_blinkCount/$_blinkTarget. Keep steady.';
          });
        }
      }
    } catch (e) {
      debugPrint('Error in _onFrame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _getInputImage(CameraImage image) {
    if (_cameraDescription == null) return null;

    final sensorOrientation = _cameraDescription!.sensorOrientation;
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation90deg;

    if (image.planes.isEmpty) return null;

    if (Platform.isIOS) {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      return InputImage.fromBytes(
        bytes: allBytes.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    // On Android, we must precisely convert YUV_420_888 to NV21
    // to support overlapping memory buffers in devices like Realme/Motorola.
    final bytes = _convertYUV420ToNV21(image);
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final numPixels = (width * height * 1.5).toInt();
    final nv21 = Uint8List(numPixels);

    int idY = 0;
    int idUV = width * height;
    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    // Y plane
    for (int y = 0; y < height; ++y) {
      final yOffset = y * yPlane.bytesPerRow;
      for (int x = 0; x < width; ++x) {
        nv21[idY++] = yBuffer[yOffset + x];
      }
    }

    // V and U planes (NV21 expects V then U)
    for (int y = 0; y < uvHeight; ++y) {
      final uvOffset = y * uvRowStride;
      for (int x = 0; x < uvWidth; ++x) {
        final bufferIndex = uvOffset + (x * uvPixelStride);
        // Sometimes UV planes are out of bounds because of cropped buffers, safe clamp:
        if (bufferIndex < vBuffer.length) {
          nv21[idUV] = vBuffer[bufferIndex];
        }
        if (bufferIndex < uBuffer.length) {
          nv21[idUV + 1] = uBuffer[bufferIndex];
        }
        idUV += 2;
      }
    }
    return nv21;
  }

  Future<void> _processDetectedFace(Face _) async {
    // We ignore the face from the stream for the final embedding.
    // Instead, we take a high-res photo for better accuracy.
    if (_processing) return;
    setState(() {
      _processing = true;
      _statusMessage = 'Capturing High-Res…';
    });

    try {
      // 1. Take Photo
      final XFile photo = await _cam!.takePicture();
      final bytes = await photo.readAsBytes();
      final img.Image? fullImage = img.decodeImage(bytes);
      if (fullImage == null) throw 'Failed to decode photo';

      // 2. Detect face in high-res photo to get precise bounding box
      final orientedImage = img.bakeOrientation(fullImage);

      final inputImage = InputImage.fromFilePath(photo.path);
      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) throw 'No face detected in high-res photo. Re-blink.';

      final mainFace = faces.first;
      final box = mainFace.boundingBox;

      // 3. Crop face with safety bounds
      final croppedFace = img.copyCrop(
        orientedImage,
        x: max(0, box.left.toInt()),
        y: max(0, box.top.toInt()),
        width: min(
          box.width.toInt(),
          orientedImage.width - max(0, box.left.toInt()),
        ),
        height: min(
          box.height.toInt(),
          orientedImage.height - max(0, box.top.toInt()),
        ),
      );

      // 4. Generate Embedding via MobileFaceNet
      setState(() => _statusMessage = 'Generating Embedding…');
      final embedding = await _frs.getEmbedding(croppedFace);

      if (widget.mode == FaceCaptureMode.registration) {
        await _registerFace(embedding);
      } else {
        await _verifyFace(embedding);
      }
    } catch (e) {
      debugPrint('Processing error: $e');
      if (mounted) {
        setState(() {
          _processing = false;
          _livenessConfirmed = false;
          _blinkCount = 0;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  // ── Registration ─────────────────────────────────────────────────────────────
  Future<void> _registerFace(List<double> landmarks) async {
    await FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    ).collection('users').doc(widget.userId).update({
      'faceEmbedding': jsonEncode(landmarks),
      'faceRegisteredAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.of(context).pop(
        const FaceCaptureResult(success: true, message: 'Face registered!'),
      );
    }
  }

  // ── Verification ─────────────────────────────────────────────────────────────
  Future<void> _verifyFace(List<double> candidateLandmarks) async {
    final doc = await FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    ).collection('users').doc(widget.userId).get();

    final data = doc.data();
    if (data == null || data['faceEmbedding'] == null) {
      if (mounted) {
        Navigator.of(context).pop(
          const FaceCaptureResult(
            success: false,
            message: 'No registered face found. Please register first.',
          ),
        );
      }
      return;
    }

    final stored = (jsonDecode(data['faceEmbedding']) as List)
        .map((e) => (e as num).toDouble())
        .toList();

    final match = FaceRecognitionService.isMatch(stored, candidateLandmarks);
    final score = FaceRecognitionService.similarity(stored, candidateLandmarks);

    debugPrint('Face verification score: $score (Match: $match)');

    if (mounted) {
      Navigator.of(context).pop(
        FaceCaptureResult(
          success: match,
          message: match
              ? 'Identity verified!'
              : 'Face did not match (Score: ${(score * 100).toStringAsFixed(1)}%).',
        ),
      );
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReg = widget.mode == FaceCaptureMode.registration;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const FaceCaptureResult(success: false),
                    ),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isReg ? 'Register Your Face' : 'Face Verification',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ── Steps indicator ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  _StepDot(label: '1. Face', done: _cameraDescription != null),
                  const Expanded(child: Divider(color: Colors.white24)),
                  _StepDot(
                    label: '2. Blink',
                    done: _blinkCount >= _blinkTarget,
                  ),
                  const Expanded(child: Divider(color: Colors.white24)),
                  _StepDot(
                    label: isReg ? '3. Save' : '3. Match',
                    done: _processing,
                  ),
                ],
              ),
            ),

            // ── Camera with oval overlay ─────────────────────────────────
            Expanded(
              child: _cam == null || !_cam!.value.isInitialized
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : ClipRect(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CameraPreview(_cam!),
                          _OvalOverlay(active: _blinkCount >= _blinkTarget),
                        ],
                      ),
                    ),
            ),

            // ── Status area ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              color: Colors.black,
              child: Column(
                children: [
                  // Blink progress dots
                  if (!_processing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_blinkTarget, (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _blinkCount
                                ? const Color(0xFF10B981)
                                : Colors.white24,
                          ),
                        );
                      }),
                    ),
                  const SizedBox(height: 12),
                  if (_processing)
                    const CircularProgressIndicator(color: Color(0xFF10B981))
                  else
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    isReg ? 'REGISTRATION MODE' : 'VERIFICATION MODE',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator dot
// ─────────────────────────────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  const _StepDot({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? const Color(0xFF10B981) : Colors.white12,
            border: Border.all(
              color: done ? const Color(0xFF10B981) : Colors.white24,
              width: 2,
            ),
          ),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Oval overlay
// ─────────────────────────────────────────────────────────────────────────────
class _OvalOverlay extends StatelessWidget {
  final bool active;
  const _OvalOverlay({required this.active});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _OvalPainter(active: active),
    );
  }
}

class _OvalPainter extends CustomPainter {
  final bool active;
  _OvalPainter({required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.72,
      height: size.height * 0.65,
    );

    // Darkened background with oval cut-out
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black54);

    // Animated border colour
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = active
            ? const Color(0xFF10B981) // Green success
            : const Color(0xFF2563EB) // Blue waiting
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_OvalPainter old) => old.active != active;
}
