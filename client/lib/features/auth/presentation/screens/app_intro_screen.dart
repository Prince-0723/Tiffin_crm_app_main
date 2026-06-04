import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';

/// First-launch intro: Lottie on violet background, then role selection.
/// Logged-in users are sent straight to auth splash → dashboard.
class AppIntroScreen extends StatefulWidget {
  const AppIntroScreen({super.key});

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen> {
  bool _routing = true;
  bool _showLottie = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final token = await SecureStorage.getAccessToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      context.go(AppRoutes.splash);
      return;
    }
    final appIntroSeen = await SecureStorage.get('app_intro_seen');
    if (!mounted) return;
    if (appIntroSeen == 'true') {
      context.go(AppRoutes.roleSelection);
      return;
    }
    setState(() {
      _routing = false;
      _showLottie = true;
    });
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    await SecureStorage.set('app_intro_seen', 'true');
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (seen) {
      context.go(AppRoutes.roleSelection);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.9),
                    const Color(0xFF3B1578),
                  ],
                ),
              ),
            ),
          ),
          if (_routing)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.onPrimary,
              ),
            )
          else if (_showLottie)
            Center(
              child: Lottie.asset(
                'assets/lottie/loading.json',
                repeat: true,
                fit: BoxFit.contain,
                width: MediaQuery.sizeOf(context).width * 0.58,
              ),
            ),
        ],
      ),
    );
  }
}
