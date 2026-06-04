import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
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
              color: _violet700,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _violet900.withValues(alpha: 0.2),
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
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TiffinCRM',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Complete tiffin business management',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Features ──────────────────────────────────────────────────────
          _sectionLabel('App Features'),
          const SizedBox(height: 10),
          ..._buildFeatureRows(),

          const SizedBox(height: 24),

          // ── How-to guides ──────────────────────────────────────────────────
          _sectionLabel('How-to Guides'),
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
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: _violet900.withValues(alpha: 0.04),
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
                        color: _violet600,
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _violet50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _border),
                            ),
                            child: Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
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
          _sectionLabel('About TiffinCRM'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: _aboutRow(
              Icons.email_outlined,
              'Contact',
              'shrivasumii@gmail.com',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeatureRows() {
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
              Expanded(child: _featureCard(left)),
              const SizedBox(width: 10),
              Expanded(
                child: right != null ? _featureCard(right) : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _featureCard((IconData, Color, Color, String, String) f) {
    final (icon, iconColor, iconBg, title, desc) = f;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _violet900.withValues(alpha: 0.04),
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
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 11,
              color: _textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value) => Row(
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
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: _textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
    ],
  );

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
