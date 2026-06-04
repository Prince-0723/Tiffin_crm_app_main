// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/notification_bell_icon.dart';
import '../../../dashboard/presentation/screens/invoices_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // ── Violet palette ────────────────────────────────────────────────────────
  static const _violet900 = Color(0xFF2D1B69);
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _bg = Color(0xFFF6F4FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _divider = Color(0xFFEEEBFA);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);
  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFCECEB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _violet700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        children: [
          // ── Account ───────────────────────────────────────────────────────
          _SectionLabel(label: 'Account'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Business Profile',
            subtitle: 'Name, address, phone, UPI for customers',
            onTap: () => context.push(AppRoutes.profile),
          ),

          const SizedBox(height: 20),

          // ── Business ──────────────────────────────────────────────────────
          _SectionLabel(label: 'Business'),
          _SettingsTile(
            icon: Icons.receipt_outlined,
            title: 'GST & extended business',
            subtitle: 'GST number and extra fields',
            onTap: () => context.push(AppRoutes.businessProfile),
          ),
          _SettingsTile(
            icon: Icons.map_outlined,
            title: 'Delivery Zones',
            subtitle: 'Manage your delivery areas',
            onTap: () => context.push(AppRoutes.zones),
          ),
          _SettingsTile(
            icon: Icons.receipt_long_outlined,
            title: 'Invoice Settings',
            subtitle: 'Templates, tax, footer text',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const InvoicesScreen())),
          ),

          const SizedBox(height: 20),

          // ── General ───────────────────────────────────────────────────────
          _SectionLabel(label: 'General'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Alerts, reminders, push settings',
            customLeading: const NotificationBellIcon(
              onPressed: null,
              size: 20,
            ),
            onTap: () => context.push(AppRoutes.notifications),
          ),

          const SizedBox(height: 32),

          // ── Logout ────────────────────────────────────────────────────────
          InkWell(
            onTap: () => context.go(AppRoutes.login),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _dangerSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _danger.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.logout_rounded, size: 18, color: _danger),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _danger,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _danger.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  // ignore:
  const _SectionLabel({super.key, required this.label});
  final String label;

  static const _textSecondary = Color(0xFF7B6DAB);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 1.2,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.customLeading,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? customLeading;

  static const _violet600 = Color(0xFF5B35D5);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _border = Color(0xFFE4DFF7);
  static const _surface = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: _violet100,
      highlightColor: _violet50,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D1B69).withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _violet50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: customLeading != null
                  ? Center(child: customLeading)
                  : Icon(icon, size: 18, color: _violet600),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    ),
  );
}
