import 'package:flutter/material.dart';

class _D {
  static const bg = Color(0xFF0E1020);
  static const surface = Color(0xFF1B1F2E);
  static const border = Color(0xFF2F3347);
  static const divider = Color(0xFF2F3347);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const violet100 = Color(0xFF241B42);
  static const violet50 = Color(0xFF141625);
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // ── Violet palette ────────────────────────────────────────────────────────
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _bg = Color(0xFFF6F4FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _D.bg : _bg,
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
          'Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Avatar card ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? _D.surface : _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? _D.border : _border),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : const Color(0xFF2D1B69).withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar circle with gradient border
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF4C2DB8), Color(0xFF6C42F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? _D.violet100 : const Color(0xFFEDE8FD),
                        ),
                        child: Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF4C2DB8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Admin User',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? _D.textPrimary : _textPrimary,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+91 9876543210',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? _D.textSecondary : _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? _D.violet100 : _violet100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? _D.border : _border),
                    ),
                    child: Text(
                      'Administrator',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFA78BFA) : _violet600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Section label ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'ACCOUNT SETTINGS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? _D.textSecondary : _textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // ── Profile tiles ─────────────────────────────────────────────
            _ProfileTile(
              icon: Icons.person_outline_rounded,
              title: 'Edit Profile',
              subtitle: 'Update name, email, phone',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              subtitle: 'Update your login password',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.store_outlined,
              title: 'Business Info',
              subtitle: 'Tiffin center name & address',
              onTap: () {},
            ),
            _ProfileTile(
              icon: Icons.phone_outlined,
              title: 'Contact Details',
              subtitle: 'Phone, WhatsApp, email',
              onTap: () {},
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile tile
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    // ignore: unused_element_parameter
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isLast;

  static const _violet600 = Color(0xFF5B35D5);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _border = Color(0xFFE4DFF7);
  static const _surface = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: isDark ? _D.violet100 : _violet100,
        highlightColor: isDark ? _D.violet50 : _violet50,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isDark ? _D.surface : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? _D.border : _border),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.20)
                    : const Color(0xFF2D1B69).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? _D.violet50 : _violet50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? _D.border : _border),
                ),
                child: Icon(icon, size: 18, color: isDark ? const Color(0xFFA78BFA) : _violet600),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? _D.textPrimary : _textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? _D.textSecondary : _textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: (isDark ? _D.textSecondary : _textSecondary).withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
