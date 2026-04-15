import 'package:flutter/material.dart';
import '../constants/motion_tokens.dart';

class SkeletonLoader extends StatelessWidget {
  final bool isCircular;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    this.isCircular = false,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? (isCircular 
            ? BorderRadius.circular(height / 2)
            : BorderRadius.circular(MotionTokens.spacingSM)),
      ),
    );
  }
}

class BranchCardSkeleton extends StatelessWidget {
  const BranchCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: MotionTokens.spacingLG,
        vertical: MotionTokens.spacingSM,
      ),
      padding: const EdgeInsets.all(MotionTokens.spacingLG),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
        boxShadow: MotionTokens.shadowSm,
      ),
      child: Row(
        children: [
          const SkeletonLoader(isCircular: true, width: 50, height: 50),
          const SizedBox(width: MotionTokens.spacingLG),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 150, height: 16),
                const SizedBox(height: MotionTokens.spacingSM),
                const SkeletonLoader(width: 200, height: 12),
                const SizedBox(height: MotionTokens.spacingSM),
                const SkeletonLoader(width: 100, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EventsListSkeleton extends StatelessWidget {
  const EventsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.symmetric(
          horizontal: MotionTokens.spacingLG,
          vertical: MotionTokens.spacingSM,
        ),
        padding: const EdgeInsets.all(MotionTokens.spacingLG),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MotionTokens.spacingSM),
          boxShadow: MotionTokens.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLoader(width: 180, height: 16),
            const SizedBox(height: MotionTokens.spacingSM),
            const SkeletonLoader(width: 120, height: 12),
            const SizedBox(height: MotionTokens.spacingSM),
            const SkeletonLoader(width: double.infinity, height: 10),
          ],
        ),
      ),
    );
  }
}