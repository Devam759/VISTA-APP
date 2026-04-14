import 'package:flutter/material.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.1 + _animation.value * 0.1,
                0.5 + _animation.value * 0.1,
                0.9 + _animation.value * 0.1,
              ],
              colors: const [
                Color(0xFFF1F5F9), // Slate 100
                Color(0xFFF8FAFC), // Slate 50
                Color(0xFFF1F5F9), // Slate 100
              ],
            ),
          ),
        );
      },
    );
  }
}

class StudentListSkeleton extends StatelessWidget {
  const StudentListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: 140, height: 16),
                    const SizedBox(height: 8),
                    const SkeletonLoader(width: 90, height: 12),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SkeletonLoader(width: 40, height: 10),
                  SizedBox(height: 6),
                  SkeletonLoader(width: 60, height: 14, borderRadius: BorderRadius.all(Radius.circular(6))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class AttendanceListSkeleton extends StatelessWidget {
  const AttendanceListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: 130, height: 16),
                    const SizedBox(height: 8),
                    const SkeletonLoader(width: 160, height: 12),
                  ],
                ),
              ),
              const SkeletonLoader(
                width: 75,
                height: 28,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ComplaintListSkeleton extends StatelessWidget {
  const ComplaintListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 4,
      padding: const EdgeInsets.all(16),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SkeletonLoader(width: 150, height: 18),
                  const SkeletonLoader(width: 70, height: 26, borderRadius: BorderRadius.all(Radius.circular(20))),
                ],
              ),
              const SizedBox(height: 16),
              const SkeletonLoader(width: double.infinity, height: 12),
              const SizedBox(height: 8),
              const SkeletonLoader(width: 200, height: 12),
              const SizedBox(height: 20),
              Container(height: 1, color: const Color(0xFFF1F5F9)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SkeletonLoader(width: 100, height: 14),
                  const Spacer(),
                  const SkeletonLoader(width: 100, height: 14),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class LeaveListSkeleton extends StatelessWidget {
  const LeaveListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 5,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: 180, height: 16),
                    const SizedBox(height: 10),
                    const SkeletonLoader(width: 120, height: 12),
                  ],
                ),
              ),
              const SkeletonLoader(
                width: 85,
                height: 30,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ShortStaySkeleton extends StatelessWidget {
  const ShortStaySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 5,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SkeletonLoader(width: 120, height: 18),
                  const SkeletonLoader(width: 75, height: 26, borderRadius: BorderRadius.all(Radius.circular(20))),
                ],
              ),
              const SizedBox(height: 16),
              const SkeletonLoader(width: double.infinity, height: 12),
              const SizedBox(height: 10),
              const SkeletonLoader(width: 180, height: 12),
            ],
          ),
        );
      },
    );
  }
}

class DashboardSummarySkeleton extends StatelessWidget {
  const DashboardSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonLoader(width: 50, height: 12),
                        SizedBox(height: 10),
                        SkeletonLoader(width: 40, height: 28),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonLoader(width: 50, height: 12),
                        SizedBox(height: 10),
                        SkeletonLoader(width: 40, height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonLoader(width: 80, height: 12),
                  SizedBox(height: 10),
                  SkeletonLoader(width: 50, height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
