import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/storefront_logo_icon.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedRole = 'vendor';

  static const _roles = [
    _RoleDef(
      key: 'vendor',
      title: 'Vendor',
      subtitle: 'Run & manage your\ntiffin centre',
      tag1: 'Orders',
      tag2: 'Payments',
      color: Color(0xFF5B2D8E),
      bgColor: Color(0xFFF0EBF9),
      tagBg: Color(0xFFF0EBF9),
      tagText: Color(0xFF5B2D8E),
      isPopular: true,
    ),
    _RoleDef(
      key: 'customer',
      title: 'Customer',
      subtitle: 'Order & track your\ndaily meals',
      tag1: 'Meals',
      tag2: 'Wallet',
      color: Color(0xFF1D9E75),
      bgColor: Color(0xFFE8F8F2),
      tagBg: Color(0xFFE8F8F2),
      tagText: Color(0xFF0F6E56),
      isPopular: false,
    ),
    _RoleDef(
      key: 'delivery_staff',
      title: 'Delivery',
      subtitle: 'Handle & complete\ndeliveries',
      tag1: 'Tasks',
      tag2: 'Routes',
      color: Color(0xFFBA7517),
      bgColor: Color(0xFFFEF5E7),
      tagBg: Color(0xFFFEF5E7),
      tagText: Color(0xFF854F0B),
      isPopular: false,
    ),
  ];

  _RoleDef get _selected => _roles.firstWhere((r) => r.key == _selectedRole);

  void _onContinue() {
    HapticFeedback.lightImpact();
    context.push(
      AppRoutes.login,
      extra: <String, String>{'selectedRole': _selectedRole},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const brandLogoPurple = Color(0xFF5B2D8E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top bar ──
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7FE),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _selected.color.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: StorefrontLogoIcon(
                      size: 36,
                      bodyColor: brandLogoPurple,
                      cutoutColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TiffinCRM',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A0A2E),
                          ),
                        ),
                        Text(
                          'Smart tiffin business management',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8B7BAE),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Notice banner ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Role label row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select your role',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8B7BAE),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '1 selected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5B2D8E),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ── Top 2 cards (Vendor + Customer) ──
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      role: _roles[0],
                      isSelected: _selectedRole == _roles[0].key,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedRole = _roles[0].key);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RoleCard(
                      role: _roles[1],
                      isSelected: _selectedRole == _roles[1].key,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedRole = _roles[1].key);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Delivery Staff — full width horizontal card ──
              _DeliveryCard(
                role: _roles[2],
                isSelected: _selectedRole == _roles[2].key,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedRole = _roles[2].key);
                },
              ),

              const Spacer(),

              // ── CTA Button ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 46,
                decoration: BoxDecoration(
                  color: _selected.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _onContinue,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Continue as ${_selected.title} →',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'By continuing you agree to our Terms. Role verified via OTP.',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFB0A3C8),
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Square Role Card (Vendor + Customer) ────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final _RoleDef role;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? role.color : const Color(0xFFEEEBF8),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: role.color.withValues(alpha: 0.15),
                    blurRadius: 0,
                    spreadRadius: 3,
                    offset: Offset.zero,
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Popular badge row
            SizedBox(
              height: 16,
              child: role.isPopular
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Popular',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFCC0000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 6),

            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: role.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _RoleIcon(roleKey: role.key, color: role.color),
              ),
            ),

            const SizedBox(height: 8),

            // Title
            Text(
              role.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A0A2E),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 2),

            // Subtitle
            Text(
              role.subtitle,
              style: const TextStyle(
                color: Color(0xFF8B7BAE),
                fontSize: 9,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            Container(height: 0.5, color: const Color(0xFFF4F1FB)),

            const SizedBox(height: 6),

            // Tags
            Row(
              children: [
                _Tag(
                  label: role.tag1,
                  bg: role.tagBg,
                  textColor: role.tagText,
                ),
                const SizedBox(width: 5),
                _Tag(
                  label: role.tag2,
                  bg: role.tagBg,
                  textColor: role.tagText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Horizontal Delivery Card ─────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final _RoleDef role;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? role.color : const Color(0xFFEEEBF8),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: role.color.withValues(alpha: 0.15),
                    blurRadius: 0,
                    spreadRadius: 3,
                    offset: Offset.zero,
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: role.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _RoleIcon(roleKey: role.key, color: role.color),
              ),
            ),

            const SizedBox(width: 12),

            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A0A2E),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role.subtitle.replaceAll('\n', ' '),
                    style: const TextStyle(
                      color: Color(0xFF8B7BAE),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Tag(
                        label: role.tag1,
                        bg: role.tagBg,
                        textColor: role.tagText,
                      ),
                      const SizedBox(width: 5),
                      _Tag(
                        label: role.tag2,
                        bg: role.tagBg,
                        textColor: role.tagText,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Chevron
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? role.bgColor : const Color(0xFFF4F1FB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isSelected ? role.color : const Color(0xFFB0A3C8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tag Widget ───────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.bg,
    required this.textColor,
  });

  final String label;
  final Color bg;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Role Icon ────────────────────────────────────────────────────────────────

class _RoleIcon extends StatelessWidget {
  const _RoleIcon({required this.roleKey, required this.color});

  final String roleKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (roleKey) {
      case 'vendor':
        return Icon(Icons.storefront_outlined, color: color, size: 22);
      case 'customer':
        return Icon(Icons.person_outline_rounded, color: color, size: 22);
      case 'delivery_staff':
        return Icon(Icons.delivery_dining_rounded, color: color, size: 22);
      default:
        return Icon(Icons.circle_outlined, color: color, size: 22);
    }
  }
}

// ── Role Definition ──────────────────────────────────────────────────────────

class _RoleDef {
  const _RoleDef({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.tag1,
    required this.tag2,
    required this.color,
    required this.bgColor,
    required this.tagBg,
    required this.tagText,
    required this.isPopular,
  });

  final String key;
  final String title;
  final String subtitle;
  final String tag1;
  final String tag2;
  final Color color;
  final Color bgColor;
  final Color tagBg;
  final Color tagText;
  final bool isPopular;
}