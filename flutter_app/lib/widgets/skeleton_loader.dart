import 'package:flutter/material.dart';

/// Shimmer skeleton loader for list items
class SkeletonLoader extends StatelessWidget {
  final bool isCircular;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonLoader({
    super.key,
    this.isCircular = false,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : borderRadius,
      ),
    );
  }
}

/// Event card skeleton loader
class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonLoader(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: 120, height: 14),
                    const SizedBox(height: 4),
                    const SkeletonLoader(width: 80, height: 10),
                  ],
                ),
              ),
              const SkeletonLoader(width: 60, height: 24),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonLoader(width: 180, height: 16),
          const SizedBox(height: 8),
          Row(
            children: [
              const SkeletonLoader(width: 80, height: 12),
              const SizedBox(width: 12),
              const SkeletonLoader(width: 80, height: 12),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: const SkeletonLoader(height: 40)),
              const SizedBox(width: 12),
              Expanded(child: const SkeletonLoader(height: 40)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pickup point card skeleton loader
class PickupPointCardSkeleton extends StatelessWidget {
  const PickupPointCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonLoader(
                width: 36,
                height: 36,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(width: 140, height: 14),
                    const SizedBox(height: 4),
                    const SkeletonLoader(width: 100, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonLoader(width: 200, height: 16),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 150, height: 12),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: const SkeletonLoader(height: 40)),
              const SizedBox(width: 12),
              Expanded(child: const SkeletonLoader(height: 40)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Flare history card skeleton loader
class FlareCardSkeleton extends StatelessWidget {
  const FlareCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SkeletonLoader(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkeletonLoader(width: 80, height: 12),
                    const SizedBox(width: 8),
                    const SkeletonLoader(width: 60, height: 12),
                  ],
                ),
                const SizedBox(height: 4),
                const SkeletonLoader(width: 120, height: 13),
              ],
            ),
          ),
          const SkeletonLoader(width: 80, height: 24),
        ],
      ),
    );
  }
}

/// Branch card skeleton loader (for map screen search results)
class BranchCardSkeleton extends StatelessWidget {
  const BranchCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SkeletonLoader(
            width: 50,
            height: 50,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 160, height: 16),
                const SizedBox(height: 4),
                const SkeletonLoader(width: 200, height: 12),
                const SizedBox(height: 4),
                const SkeletonLoader(width: 100, height: 10),
              ],
            ),
          ),
          const SkeletonLoader(width: 60, height: 30),
        ],
      ),
    );
  }
}

/// Profile header skeleton loader
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SkeletonLoader(
            width: 80,
            height: 80,
            isCircular: true,
          ),
          const SizedBox(height: 16),
          const SkeletonLoader(width: 150, height: 20),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 180, height: 14),
          const SizedBox(height: 10),
          const SkeletonLoader(width: 100, height: 24),
        ],
      ),
    );
  }
}

/// Stats card skeleton loader
class StatsCardSkeleton extends StatelessWidget {
  const StatsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const SkeletonLoader(
                  width: 40,
                  height: 40,
                  isCircular: true,
                ),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 40, height: 20),
                const SizedBox(height: 4),
                const SkeletonLoader(width: 60, height: 12),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: Colors.grey[300],
          ),
          Expanded(
            child: Column(
              children: [
                const SkeletonLoader(
                  width: 40,
                  height: 40,
                  isCircular: true,
                ),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 40, height: 20),
                const SizedBox(height: 4),
                const SkeletonLoader(width: 60, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu item skeleton loader
class MenuItemSkeleton extends StatelessWidget {
  const MenuItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SkeletonLoader(
            width: 36,
            height: 36,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 120, height: 14),
                const SizedBox(height: 4),
                const SkeletonLoader(width: 160, height: 11),
              ],
            ),
          ),
          const SkeletonLoader(width: 24, height: 24),
        ],
      ),
    );
  }
}