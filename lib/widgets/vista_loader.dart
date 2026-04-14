import 'package:flutter/material.dart';

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
    final primaryColor = color ?? const Color(0xFF1E3A8A);
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size * 0.25, // Smaller radius for the classic indicator
            height: size * 0.25,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              backgroundColor: primaryColor.withValues(alpha: 0.1),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: TextStyle(
                color: primaryColor.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
