import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.role});

  final String role;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _scheduleNavigation();
  }

  void _scheduleNavigation() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _navigateByRole(context, widget.role);
    });
  }

  static void _navigateByRole(BuildContext context, String role) {
    switch (role) {
      case 'vendor':
        context.go(AppRoutes.dashboard);
        break;
      case 'customer':
        context.go(AppRoutes.customerHome);
        break;
      case 'delivery_staff':
        context.go(AppRoutes.deliveryDashboard);
        break;
      case 'admin':
        context.go(AppRoutes.adminDashboard);
        break;
      default:
        context.go(AppRoutes.dashboard);
    }
  }

  static String _roleDisplayName(String role) {
    switch (role) {
      case 'vendor':
        return 'Vendor';
      case 'customer':
        return 'Customer';
      case 'delivery_staff':
        return 'Delivery Partner';
      case 'admin':
        return 'Admin';
      default:
        return 'Vendor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleName = _roleDisplayName(widget.role);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome back!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Logging you in as $roleName...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
