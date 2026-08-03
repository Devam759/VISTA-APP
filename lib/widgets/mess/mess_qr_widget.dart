import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/mess_model.dart';
import '../../models/vista_user.dart';
import '../../services/mess_qr_service.dart';

class MessQrWidget extends StatefulWidget {
  final VistaUser student;

  const MessQrWidget({super.key, required this.student});

  @override
  State<MessQrWidget> createState() => _MessQrWidgetState();
}

class _MessQrWidgetState extends State<MessQrWidget> {
  Timer? _timer;
  int _secondsRemaining = 30;
  String _qrPayload = '';
  bool _isWindowActive = true;

  @override
  void initState() {
    super.initState();
    _checkWindowAndRegenerate();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkWindowAndRegenerate() {
    final now = DateTime.now();
    final active = MessTimings.isQrWindowActive(now);
    setState(() {
      _isWindowActive = active;
      if (active) {
        _qrPayload = MessQrService.generateSecureQrPayload(
          widget.student.uid,
          widget.student.rollNo ?? 'STUDENT',
        );
      } else {
        _qrPayload = '';
      }
      _secondsRemaining = 30;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _checkWindowAndRegenerate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsRemaining / 30.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.qr_code_2, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 8),
                  Text(
                    'My Mess QR Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Render Encrypted QR Code OR Unavailable Placeholder
          if (_isWindowActive && _qrPayload.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDBE3F4)),
              ),
              child: QrImageView(
                data: _qrPayload,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1E3A8A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F2460),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: const Color(0xFFDBE3F4),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF145AF2)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Auto-refreshes in ${_secondsRemaining}s',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _checkWindowAndRegenerate,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.refresh, size: 20, color: Color(0xFF145AF2)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Screenshots will fail authentication. Present live QR at Mess Entry.',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Container(
              width: 224.0,
              height: 224.0,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'QR Not Available',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
