import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieEmptyState extends StatelessWidget {
  const LottieEmptyState({
    super.key,
    this.message = 'No items found',
    this.lottieAsset = 'assets/lottie/empty_state.json',
    this.size = 200,
  });

  final String message;
  final String lottieAsset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              lottieAsset,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
