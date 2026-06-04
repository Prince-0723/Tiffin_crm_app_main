import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

class ShimmerOrderListItem extends StatelessWidget {
  const ShimmerOrderListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              shape: BoxShape.circle,
            ),
          ),
          title: Container(height: 16, color: AppColors.surfaceContainerLowest),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 6),
            height: 12,
            width: 120,
            color: AppColors.surfaceContainerLowest,
          ),
          trailing: Container(height: 24, width: 60, color: AppColors.surfaceContainerLowest),
        ),
      ),
    );
  }
}

class ShimmerStaffListItem extends StatelessWidget {
  const ShimmerStaffListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle),
          ),
          title: Container(height: 16, color: AppColors.surfaceContainerLowest),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 6),
            height: 12,
            width: 100,
            color: AppColors.surfaceContainerLowest,
          ),
        ),
      ),
    );
  }
}

class ShimmerNotificationItem extends StatelessWidget {
  const ShimmerNotificationItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          title: Container(height: 14, color: AppColors.surfaceContainerLowest),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 8),
            height: 12,
            color: AppColors.surfaceContainerLowest,
          ),
          trailing: Container(height: 12, width: 40, color: AppColors.surfaceContainerLowest),
        ),
      ),
    );
  }
}

class ShimmerProfileLines extends StatelessWidget {
  const ShimmerProfileLines({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 80, color: AppColors.surfaceContainerLowest),
                const SizedBox(height: 8),
                Container(height: 48, color: AppColors.surfaceContainerLowest),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShimmerCardBlock extends StatelessWidget {
  const ShimmerCardBlock({super.key, this.height = 80});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Card(
        child: Container(
          height: height,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(height: 16, width: 120, color: AppColors.surfaceContainerLowest),
              const SizedBox(height: 8),
              Container(height: 12, width: 180, color: AppColors.surfaceContainerLowest),
            ],
          ),
        ),
      ),
    );
  }
}
