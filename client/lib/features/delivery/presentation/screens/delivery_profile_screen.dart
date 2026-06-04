import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/models/user_model.dart';
import '../../data/delivery_api.dart';

class DeliveryProfileScreen extends StatefulWidget {
  const DeliveryProfileScreen({super.key});

  @override
  State<DeliveryProfileScreen> createState() => _DeliveryProfileScreenState();
}

class _DeliveryProfileScreenState extends State<DeliveryProfileScreen> {
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
  static const _success = Color(0xFF0F7B0F);
  static const _successSoft = Color(0xFFE6F4EA);
  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFCECEB);

  // ── State ─────────────────────────────────────────────────────────────────
  UserModel? _user;
  bool _loading = true;
  bool _updatingActive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await AuthApi.getProfile();
      // Debug log removed to satisfy avoid_print lint.

      if (mounted) setState(() => _user = user);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setActive(bool value) async {
    setState(() => _updatingActive = true);
    try {
      await DeliveryApi.updateMe({'is_active': value});

      if (mounted) {
        setState(
          () => _user = _user != null
              ? UserModel(
                  id: _user!.id,
                  phone: _user!.phone,
                  role: _user!.role,
                  name: _user!.name,
                  businessName: _user!.businessName,
                  email: _user!.email,
                  logoUrl: _user!.logoUrl,
                  isActive: value,
                  fcmToken: _user!.fcmToken,
                )
              : null,
        );
        AppSnackbar.success(
          context,
          value ? 'You are now active for deliveries' : 'You are now inactive',
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _updatingActive = false);
    }
  }

  Future<void> _logout() async {
    await AuthApi.logout();
    await AuthSession.clearLocalSession();
    if (!mounted) return;
    GoRouter.of(context).go(AppRoutes.login);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: _violet600, strokeWidth: 2.5),
      );
    }

    final u = _user;

    return RefreshIndicator(
      color: _violet600,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).padding.bottom + 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Identity card ───────────────────────────────────────────────
            if (u != null) _buildIdentityCard(u),
            const SizedBox(height: 24),

            // ── Availability section ────────────────────────────────────────
            _sectionLabel('Availability'),
            const SizedBox(height: 10),
            _buildAvailabilityCard(u),
            const SizedBox(height: 24),

            // ── Info section ────────────────────────────────────────────────
            if (u != null) ...[
              _sectionLabel('Account Info'),
              const SizedBox(height: 10),
              _buildInfoCard(u),
              const SizedBox(height: 32),
            ],

            // ── Logout ──────────────────────────────────────────────────────
            InkWell(
              onTap: _logout,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: _danger,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
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
      ),
    );
  }

  // ── Identity card ─────────────────────────────────────────────────────────
  Widget _buildIdentityCard(UserModel u) {
    final initials = _getInitials(u.name);
    final isActive = u.isActive;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _violet900.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top accent
          Container(
            height: 4,
            decoration: const BoxDecoration(
              color: _violet700,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                // Avatar with status dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: isActive ? _violet100 : _divider,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isActive ? _border : _border),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isActive ? _violet700 : _textSecondary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -3,
                      right: -3,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isActive ? _success : _textSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: _surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name.isEmpty ? 'Delivery Staff' : u.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        u.phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? _successSoft : _divider,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isActive
                                ? _success.withValues(alpha: 0.3)
                                : _border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isActive ? _success : _textSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isActive
                                  ? 'Available for delivery'
                                  : 'Currently inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isActive ? _success : _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Meta row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Divider(color: _divider, height: 1, thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            child: Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 13,
                  color: _textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  'Delivery Staff · ${u.role}',
                  style: const TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Availability card ─────────────────────────────────────────────────────
  Widget _buildAvailabilityCard(UserModel? u) {
    final isActive = u?.isActive ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive ? _successSoft : _divider,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isActive
                  ? Icons.directions_bike_rounded
                  : Icons.do_not_disturb_on_outlined,
              size: 18,
              color: isActive ? _success : _textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Active for Deliveries' : 'Not Available',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  isActive
                      ? 'You will receive new delivery assignments'
                      : 'You won\'t receive new assignments',
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Custom toggle
          if (_updatingActive)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _violet600,
              ),
            )
          else
            GestureDetector(
              onTap: u != null ? () => _setActive(!isActive) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 28,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isActive ? _violet600 : const Color(0xFFD0C8E8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? _violet700 : const Color(0xFFB0A8D0),
                    width: 1.5,
                  ),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isActive
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      isActive ? Icons.check_rounded : Icons.close_rounded,
                      size: 12,
                      color: isActive ? _violet600 : const Color(0xFFB0A8D0),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────
  Widget _buildInfoCard(UserModel u) => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        _infoRow(
          Icons.person_outline_rounded,
          'Full Name',
          u.name.isEmpty ? '—' : u.name,
          true,
        ),
        Divider(
          color: _divider,
          height: 1,
          thickness: 1,
          indent: 56,
          endIndent: 0,
        ),
        _infoRow(Icons.phone_outlined, 'Phone', u.phone, false),
        if (u.email != null && u.email!.isNotEmpty) ...[
          Divider(
            color: _divider,
            height: 1,
            thickness: 1,
            indent: 56,
            endIndent: 0,
          ),
          _infoRow(Icons.email_outlined, 'Email', u.email!, false),
        ],
      ],
    ),
  );

  Widget _infoRow(IconData icon, String label, String value, bool isFirst) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _violet50,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _border),
              ),
              child: Icon(icon, size: 15, color: _violet600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: _violet600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}
