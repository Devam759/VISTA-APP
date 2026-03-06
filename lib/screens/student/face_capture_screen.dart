import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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
  late FaceDetector _detector;
  final FaceRecognitionService _frs = FaceRecognitionService();

  // ── Liveness state ──────────────────────────────────────────────────────────
  bool _livenessOk = false;
  int _blinkCount = 0;
  bool _eyesWereClosed = false;
  static const _blinkTarget = 1; // one deliberate blink required

  String _statusMessage = '';
  bool _processing = false;
  bool _frameProcessing = false;

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
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    // Front camera
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cam = CameraController(front, ResolutionPreset.medium, enableAudio: false);
    await _cam!.initialize();

    if (mounted) {
      setState(() {
        _statusMessage = widget.mode == FaceCaptureMode.registration
            ? 'Centre your face in the oval, then blink once to register.'
            : 'Centre your face in the oval, then blink once to verify.';
      });
      _cam!.startImageStream(_onFrame);
    }
  }

  // ── Frame handler ────────────────────────────────────────────────────────────
  Future<void> _onFrame(CameraImage camImg) async {
    if (_livenessOk || _frameProcessing || _processing) return;
    _frameProcessing = true;

    try {
      final bytes = _concatenatePlanes(camImg.planes);
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(camImg.width.toDouble(), camImg.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: camImg.planes[0].bytesPerRow,
        ),
      );

      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          setState(
            () => _statusMessage = 'No face detected. Centre your face.',
          );
        }
        return;
      }

      final face = faces.first;
      final leftEye = face.leftEyeOpenProbability ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;
      final eyesClosed = leftEye < 0.25 && rightEye < 0.25;

      // Blink = eyes were closed and are now open again
      if (!eyesClosed && _eyesWereClosed) {
        _blinkCount++;
      }
      _eyesWereClosed = eyesClosed;

      if (_blinkCount >= _blinkTarget) {
        _livenessOk = true;
        await _cam!.stopImageStream();
        if (mounted) {
          setState(
            () => _statusMessage = 'Liveness confirmed! Processing face…',
          );
        }

        // Process the last detected face immediately (landmarks already available)
        await _processDetectedFace(face);
        return;
      }

      if (mounted) {
        setState(() {
          _statusMessage = eyesClosed
              ? 'Eyes closed… open them to complete the blink.'
              : widget.mode == FaceCaptureMode.registration
              ? 'Good! Now blink once to register.'
              : 'Good! Now blink once to verify.';
        });
      }
    } finally {
      _frameProcessing = false;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final buf = WriteBuffer();
    for (final p in planes) {
      buf.putUint8List(p.bytes);
    }
    return buf.done().buffer.asUint8List();
  }

  // ── Process the confirmed face ───────────────────────────────────────────────
  Future<void> _processDetectedFace(Face face) async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final landmarks = _frs.extractLandmarks(face);

      if (widget.mode == FaceCaptureMode.registration) {
        await _registerFace(landmarks);
      } else {
        await _verifyFace(landmarks);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: ${e.toString()}. Try again.';
          _processing = false;
          _livenessOk = false;
          _blinkCount = 0;
          _eyesWereClosed = false;
        });
        _cam!.startImageStream(_onFrame);
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

    if (mounted) {
      Navigator.of(context).pop(
        FaceCaptureResult(
          success: match,
          message: match
              ? 'Identity verified!'
              : 'Face did not match. Please try again.',
        ),
      );
    }
  }

  @override
  void dispose() {
    _cam?.stopImageStream();
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
                  _StepDot(
                    label: '1. Face',
                    done: _blinkCount > 0 || _processing,
                  ),
                  const Expanded(child: Divider(color: Colors.white24)),
                  _StepDot(label: '2. Blink', done: _livenessOk),
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
                          _OvalOverlay(livenessOk: _livenessOk),
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
                  if (!_livenessOk && !_processing)
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
                        color: _livenessOk
                            ? const Color(0xFF10B981)
                            : Colors.white70,
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
  final bool livenessOk;
  const _OvalOverlay({required this.livenessOk});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _OvalPainter(livenessOk: livenessOk),
    );
  }
}

class _OvalPainter extends CustomPainter {
  final bool livenessOk;
  _OvalPainter({required this.livenessOk});

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
        ..color = livenessOk
            ? const Color(0xFF10B981) // green ✓
            : const Color(0xFF2563EB) // blue waiting
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_OvalPainter old) => old.livenessOk != livenessOk;
}
