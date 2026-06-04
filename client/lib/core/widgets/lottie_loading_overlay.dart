import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieLoadingOverlay extends StatelessWidget {
  const LottieLoadingOverlay({
    super.key,
    this.size = 120,
    this.asset = 'assets/lottie/loading.json',
  });

  final double size;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(
          asset,
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }
}
