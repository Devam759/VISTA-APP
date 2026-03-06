import 'package:flutter/material.dart';

enum FaceCaptureMode { registration, verification }

class FaceCaptureResult {
  final bool success;
  final String? message;
  const FaceCaptureResult({required this.success, this.message});
}

class FaceCaptureScreen extends StatelessWidget {
  final String userId;
  final FaceCaptureMode mode;

  const FaceCaptureScreen({
    super.key,
    required this.userId,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Capture')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                'Face verification and attendance marking are not supported on the web version. Please use the mobile app to mark your attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
