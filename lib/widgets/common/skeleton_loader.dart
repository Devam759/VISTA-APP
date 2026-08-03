import 'package:flutter/material.dart';
import 'vista_loader.dart';

/// Legacy skeleton placeholder fallbacks — now routing to clean ThreeBodyLoader or VistaClassicLoader.
class SkeletonLoader extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.height = 20,
    this.width = double.infinity,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: height,
        width: width,
        child: const ThreeBodyLoader(size: 20),
      ),
    );
  }
}

class DashboardSummarySkeleton extends StatelessWidget {
  const DashboardSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: ThreeBodyLoader(size: 35),
      ),
    );
  }
}

class LeaveListSkeleton extends StatelessWidget {
  const LeaveListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: ThreeBodyLoader(size: 35),
      ),
    );
  }
}

class ComplaintListSkeleton extends StatelessWidget {
  const ComplaintListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: ThreeBodyLoader(size: 35),
      ),
    );
  }
}

class AttendanceListSkeleton extends StatelessWidget {
  const AttendanceListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: VistaClassicLoader(size: 35),
      ),
    );
  }
}

class ShortStaySkeleton extends StatelessWidget {
  const ShortStaySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: ThreeBodyLoader(size: 35),
      ),
    );
  }
}

class StudentListSkeleton extends StatelessWidget {
  const StudentListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: ThreeBodyLoader(size: 35),
      ),
    );
  }
}
