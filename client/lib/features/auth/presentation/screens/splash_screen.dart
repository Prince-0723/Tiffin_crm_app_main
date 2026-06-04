import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notifications/notification_badge_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/auth_api.dart';
import '../../../../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final router = GoRouter.of(context);

    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      router.go(AppRoutes.roleSelection);
      return;
    }

    try {
      final user = await AuthApi.getProfile();
      if (!mounted) return;
      await SecureStorage.saveUserRole(user.role);
      await SecureStorage.saveUserId(user.id);
      await NotificationBadgeService.refreshNow();
      await NotificationService().registerTokenAfterLogin();
      if (user.role == 'vendor' && !user.isVendorProfileComplete) {
        router.go(AppRoutes.vendorOnboarding, extra: user.phone);
        return;
      }
      if (!mounted) return;
      router.go(_routeForRole(user.role));
    } catch (_) {
      try {
        final refreshed = await _refreshToken();
        if (refreshed && mounted) {
          final user = await AuthApi.getProfile();
          if (!mounted) return;
          await SecureStorage.saveUserRole(user.role);
          await SecureStorage.saveUserId(user.id);
          await NotificationBadgeService.refreshNow();
          await NotificationService().registerTokenAfterLogin();
          if (user.role == 'vendor' && !user.isVendorProfileComplete) {
            router.go(AppRoutes.vendorOnboarding, extra: user.phone);
            return;
          }
          if (!mounted) return;
          router.go(_routeForRole(user.role));
          return;
        }
      } catch (_) {}
      await AuthSession.clearLocalSession();
      if (!mounted) return;
      router.go(AppRoutes.roleSelection);
    }
  }

  Future<bool> _refreshToken() async {
    final refresh = await SecureStorage.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    final response = await AuthApi.refreshToken(refresh);
    if (response != null) {
      await SecureStorage.saveAccessToken(response.accessToken);
      await SecureStorage.saveRefreshToken(response.refreshToken);
      return true;
    }
    return false;
  }

  String _routeForRole(String role) {
    switch (role) {
      case 'vendor':
        return AppRoutes.dashboard;
      case 'customer':
        return AppRoutes.customerHome;
      case 'delivery_staff':
        return AppRoutes.deliveryDashboard;
      case 'admin':
        return AppRoutes.adminDashboard;
      default:
        return AppRoutes.dashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.storefront_rounded,
                size: 112,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
