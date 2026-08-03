import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// THREE-BODY WOBBLE LOADER (Based on the Three-Body Animation)
/// Used everywhere except Attendance-related screens which use VistaClassicLoader.
/// Standardized consistent sizing throughout the app (35px for cards/pages, 20px for inline buttons).
/// ─────────────────────────────────────────────────────────────────────────────
class ThreeBodyLoader extends StatefulWidget {
  final double size;
  final String? message;
  final Color? color;

  const ThreeBodyLoader({
    super.key,
    this.size = 35.0,
    this.message,
    this.color,
  });

  @override
  State<ThreeBodyLoader> createState() => _ThreeBodyLoaderState();
}

class _ThreeBodyLoaderState extends State<ThreeBodyLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Speed * 2.5 equivalent
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Consistent effective sizing across the entire application
  double get _effectiveSize => widget.size <= 24.0 ? 20.0 : 35.0;

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? const Color(0xFF1E3A8A);
    final currentSize = _effectiveSize;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double angle = _controller.value * 2 * math.pi;
              return SizedBox(
                width: currentSize,
                height: currentSize,
                child: Transform.rotate(
                  angle: angle,
                  child: Stack(
                    children: [
                      // Dot 1
                      _buildDot(
                        index: 0,
                        alignment: Alignment.bottomLeft,
                        rotation: math.pi / 3, // 60 deg
                        originY: 0.85,
                        color: themeColor,
                        size: currentSize,
                      ),
                      // Dot 2
                      _buildDot(
                        index: 1,
                        alignment: Alignment.bottomRight,
                        rotation: -math.pi / 3, // -60 deg
                        originY: 0.85,
                        color: themeColor,
                        size: currentSize,
                      ),
                      // Dot 3
                      _buildDot(
                        index: 2,
                        alignment: Alignment.bottomCenter,
                        offsetFactor: 1.16666,
                        color: themeColor,
                        size: currentSize,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.message!,
              style: TextStyle(
                color: themeColor,
                fontSize: 13,
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

  Widget _buildDot({
    required int index,
    required Alignment alignment,
    double rotation = 0.0,
    double originY = 0.5,
    double offsetFactor = 0.0,
    required Color color,
    required double size,
  }) {
    // Wobble Animation matching CSS wobble1 & wobble2
    final double cycleProgress = (_controller.value * 2.5) % 1.0;
    
    // Calculate delayed progress for each dot
    double dotProgress = cycleProgress;
    if (index == 0) {
      dotProgress = (cycleProgress - 0.3) % 1.0;
    } else if (index == 1) {
      dotProgress = (cycleProgress - 0.15) % 1.0;
    }

    final double sineVal = math.sin(dotProgress * 2 * math.pi);
    final double factor = (sineVal + 1.0) / 2.0; // 0.0 to 1.0
    
    // Scale & Opacity wobble
    final double scale = 1.0 - (0.35 * factor);
    final double opacity = 1.0 - (0.2 * factor);

    // Translation wobble
    final double direction = (index == 2) ? 1.0 : -1.0;
    final double translateY = direction * (size * 0.22) * factor;

    Widget dotChild = Transform.translate(
      offset: Offset(0.0, translateY),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );

    // Position & rotation transform
    if (rotation != 0.0) {
      dotChild = Transform(
        alignment: FractionalOffset(0.5, originY),
        transform: Matrix4.rotationZ(rotation),
        child: dotChild,
      );
    }

    if (offsetFactor != 0.0) {
      dotChild = Transform.translate(
        offset: Offset(size * 0.3 * (offsetFactor - 0.5), size * 0.05),
        child: dotChild,
      );
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: index == 2
            ? const EdgeInsets.only(bottom: 0)
            : const EdgeInsets.only(bottom: 5),
        child: dotChild,
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// VISTA CLASSIC LOADER (Used for Attendance-related screens & bottom circle loaders)
/// ─────────────────────────────────────────────────────────────────────────────
class VistaClassicLoader extends StatelessWidget {
  final double size;
  final String? message;
  final Color? color;

  const VistaClassicLoader({
    super.key,
    this.size = 28.0,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? const Color(0xFF1E3A8A);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              backgroundColor: primaryColor.withValues(alpha: 0.12),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: primaryColor.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Compatibility aliases
typedef VISTALoader = ThreeBodyLoader;      // Loader used for the rest of the app
typedef BoxLoader = ThreeBodyLoader;        // Box loader replaced with Three-body loader
typedef ClassicLoader = VistaClassicLoader; // Keeps circle loader for attendance related loaders
