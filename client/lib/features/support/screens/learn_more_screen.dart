import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';

class _D {
  static const bg = Color(0xFF0E1020);
  static const surface = Color(0xFF1B1F2E);
  static const border = Color(0xFF2F3347);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const violet100 = Color(0xFF241B42);
  static const violet50 = Color(0xFF141625);
}

class LearnMoreScreen extends StatelessWidget {
  const LearnMoreScreen({super.key});

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

  // ── Features ──────────────────────────────────────────────────────────────
  static const _features = [
    (
      Icons.people_outline_rounded,
      Color(0xFF4C2DB8),
      Color(0xFFEDE8FD),
      'Customer Management',
      'Add, manage and track all your tiffin customers in one place',
    ),
    (
      Icons.edit_note_rounded,
      Color(0xFF0F6E56),
      Color(0xFFE1F5EE),
      'Meal Plan Builder',
      'Create daily, weekly & monthly plans with custom meal slots',
    ),
    (
      Icons.payments_outlined,
      Color(0xFF854F0B),
      Color(0xFFFAEEDA),
      'Payment Tracking',
      'Record cash & Razorpay payments, track dues and history',
    ),
    (
      Icons.receipt_long_outlined,
      Color(0xFF185FA5),
      Color(0xFFE6F1FB),
      'Invoice Generation',
      'Auto-generate and share professional invoices with customers',
    ),
    (
      Icons.delivery_dining_rounded,
      Color(0xFF993556),
      Color(0xFFFBEAF0),
      'Delivery Management',
      'Assign deliveries, track staff locations on live map',
    ),
    (
      Icons.map_outlined,
      Color(0xFF0F6E56),
      Color(0xFFE1F5EE),
      'Zone-wise Delivery',
      'Organize deliveries by area zones for efficient routing',
    ),
    (
      Icons.bar_chart_rounded,
      Color(0xFF4C2DB8),
      Color(0xFFEDE8FD),
      'Reports & Analytics',
      'Daily, weekly, monthly revenue and subscription insights',
    ),
    (
      Icons.notifications_outlined,
      Color(0xFF854F0B),
      Color(0xFFFAEEDA),
      'Smart Notifications',
      'Get alerts for dues, deliveries and new orders',
    ),
  ];

  // ── How-to guides ─────────────────────────────────────────────────────────
  static const _guides = [
    (
      Icons.person_add_outlined,
      '1',
      'Add your first customer',
      'Customers → + button → Fill details → Save',
    ),
    (
      Icons.edit_note_rounded,
      '2',
      'Create a meal plan',
      'Meal Plans → New Plan → Add slots & items → Create',
    ),
    (
      Icons.assignment_ind_outlined,
      '3',
      'Assign plan to customer',
      'Meal Plans → Assign to Customer → Select customer',
    ),
    (
      Icons.payments_outlined,
      '4',
      'Record a payment',
      'Finance → Collect Payment → Select customer → Save',
    ),
    (
      Icons.receipt_long_outlined,
      '5',
      'Generate invoice',
      'Invoice Settings → Generate → Select period → Create',
    ),
    (
      Icons.people_alt_outlined,
      '6',
      'Add delivery staff',
      'Delivery Staff → Add Staff → Fill details → Save',
    ),
  ];

  Color _getFeatureIconColor(Color lightColor, bool isDark) {
    if (!isDark) return lightColor;
    final val = lightColor.value;
    if (val == 0xFF4C2DB8) return const Color(0xFFA78BFA); // Violet
    if (val == 0xFF0F6E56) return const Color(0xFF34D399); // Green
    if (val == 0xFF854F0B) return const Color(0xFFFBBF24); // Orange
    if (val == 0xFF185FA5) return const Color(0xFF60A5FA); // Blue
    if (val == 0xFF993556) return const Color(0xFFF472B6); // Pink/Red
    return lightColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _D.bg : _bg,
      appBar: AppBar(
        backgroundColor: _violet700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Learn More',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).padding.bottom + 40,
        ),
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? _D.surface : _violet700,
              borderRadius: BorderRadius.circular(16),
              border: isDark ? Border.all(color: _D.border) : null,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : _violet900.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? _D.violet100 : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    size: 26,
                    color: isDark ? AppColors.primaryLight : Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TiffinCRM',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? _D.textPrimary : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Complete tiffin business management',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? _D.textSecondary : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Features ──────────────────────────────────────────────────────
          _sectionLabel('App Features', isDark),
          const SizedBox(height: 10),
          ..._buildFeatureRows(isDark),

          const SizedBox(height: 24),

          // ── How-to guides ──────────────────────────────────────────────────
          _sectionLabel('How-to Guides', isDark),
          const SizedBox(height: 10),
          ...(_guides.map((g) {
            final (icon, step, title, desc) = g;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: isDark ? _D.surface : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? _D.border : _border),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.1) : _violet900.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Step badge
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primary : _violet600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          step,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? _D.textPrimary : _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? _D.violet50 : _violet50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? _D.border : _border),
                            ),
                            child: Text(
                              desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? _D.textSecondary : _textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          })),

          const SizedBox(height: 24),

          // ── About ──────────────────────────────────────────────────────────
          _sectionLabel('About TiffinCRM', isDark),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? _D.surface : _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? _D.border : _border),
            ),
            child: _aboutRow(
              Icons.email_outlined,
              'Contact',
              'shrivasumii@gmail.com',
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeatureRows(bool isDark) {
    final rows = <Widget>[];
    for (int i = 0; i < _features.length; i += 2) {
      final left = _features[i];
      final right = i + 1 < _features.length ? _features[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _featureCard(left, isDark)),
              const SizedBox(width: 10),
              Expanded(
                child: right != null ? _featureCard(right, isDark) : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _featureCard((IconData, Color, Color, String, String) f, bool isDark) {
    final (icon, iconColor, iconBg, title, desc) = f;
    final activeIconColor = _getFeatureIconColor(iconColor, isDark);
    final activeIconBg = isDark ? activeIconColor.withValues(alpha: 0.15) : iconBg;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? _D.surface : _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? _D.border : _border),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.1) : _violet900.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: activeIconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: activeIconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? _D.textPrimary : _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? _D.textSecondary : _textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value, bool isDark) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark ? _D.violet50 : _violet50,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: isDark ? _D.border : _border),
        ),
        child: Icon(icon, size: 15, color: isDark ? AppColors.primaryLight : _violet600),
      ),
      const SizedBox(width: 12),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? _D.textSecondary : _textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      const Spacer(),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? _D.textPrimary : _textPrimary,
        ),
      ),
    ],
  );

  Widget _sectionLabel(String text, bool isDark) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: isDark ? AppColors.primary : _violet600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? _D.textSecondary : _textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}
