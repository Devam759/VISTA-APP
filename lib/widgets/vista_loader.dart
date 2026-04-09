import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class VISTALoader extends StatelessWidget {
  final double size;
  final String? message;
  final Color? color;

  const VISTALoader({
    super.key,
    this.size = 120,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              'assets/animation/loading_animation_blue.lottie',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to standard loader if lottie fails for any reason
                return Center(
                  child: CircularProgressIndicator(
                    color: color ?? const Color(0xFF1E3A8A),
                    strokeWidth: 3,
                  ),
                );
              },
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: color ?? const Color(0xFF1E3A8A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
