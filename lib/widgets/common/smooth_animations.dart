import 'package:flutter/material.dart';

/// A widget that applies a smooth fade-in and slide-up animation to its child.
/// Useful for list items or page sections to create a premium staggered effect.
class SmoothEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final bool enabled;

  const SmoothEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.offset = const Offset(0, 30),
    this.enabled = true,
  });


  @override
  State<SmoothEntrance> createState() => _SmoothEntranceState();
}

class _SmoothEntranceState extends State<SmoothEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _slideAnimation = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.enabled) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A pre-configured AnimatedSwitcher for consistent state transitions.
class SmoothSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Axis axis;

  const SmoothSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.axis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axis: axis,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
