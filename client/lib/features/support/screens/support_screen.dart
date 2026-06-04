import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
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

  // ── Support info ──────────────────────────────────────────────────────────
  static const _whatsappNumber = '+919876543210';
  static const _phoneNumber = '+919876543210';
  static const _emailAddress = 'shrivasumii@gmail.com';

  int? _expandedFaq;

  static const _faqs = [
    (
      'How do I add a new customer?',
      'Go to Customers from the dashboard, tap the + button, fill in the customer details and tap Save. The customer will be immediately available for subscriptions and payments.',
    ),
    (
      'How do I create a meal plan?',
      'Navigate to Standard Meal Plans from the menu. Tap New Plan, enter the plan name, price, type (daily/weekly/monthly), and add meal slots with items. Tap Create Plan to save.',
    ),
    (
      'How do I record a payment?',
      'Go to Finance & Payments from the bottom navigation. Select the customer, enter the amount, choose payment method (Cash or Razorpay), and tap Record Payment.',
    ),
    (
      'How do I assign a delivery person?',
      'Go to Delivery Staff, add a staff member, then from Daily Orders assign the delivery to that staff member. They will receive the order on their delivery app.',
    ),
    (
      'How do I generate an invoice?',
      'Go to Settings → Invoice Settings. Tap Generate, select the customer and billing period, then tap Generate Invoice. The invoice will appear in the list.',
    ),
    (
      'How do I track delivery on the map?',
      'Open the delivery staff list and tap Track next to a staff member. You can also view all deliveries on the map from the delivery dashboard.',
    ),
  ];

  Future<void> _openWhatsApp() async {
    final number = _whatsappNumber.replaceAll('+', '').replaceAll(' ', '');
    final uri = Uri.parse(
      'https://wa.me/$number?text=Hello, I need support with TiffinCRM app.',
    );
    if (await canLaunchUrl(uri))
      // ignore: curly_braces_in_flow_control_structures
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPhone() async {
    final uri = Uri.parse('tel:$_phoneNumber');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openEmail() async {
    final uri = Uri.parse(
      'mailto:$_emailAddress?subject=TiffinCRM Support&body=Hello, I need help with...',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

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
          'Support',
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
          // ── Hero card ──────────────────────────────────────────────────────
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
                    Icons.headset_mic_rounded,
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
                        'We\'re here to help!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Available 24/7, always here for you',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Contact section ────────────────────────────────────────────────
          _sectionLabel('Contact Us'),
          const SizedBox(height: 10),

          // WhatsApp
          _contactCard(
            icon: Icons.chat_rounded,
            iconBg: const Color(0xFFE6F4EA),
            iconColor: const Color(0xFF1B7A3A),
            title: 'WhatsApp',
            subtitle: 'Chat with us instantly',
            badgeText: 'Fastest',
            badgeColor: const Color(0xFF1B7A3A),
            badgeBg: const Color(0xFFE6F4EA),
            onTap: _openWhatsApp,
          ),
          const SizedBox(height: 8),

          // Call
          _contactCard(
            icon: Icons.phone_rounded,
            iconBg: _violet100,
            iconColor: _violet600,
            title: 'Call Us',
            subtitle: _phoneNumber,
            onTap: _openPhone,
          ),
          const SizedBox(height: 8),

          // Email
          _contactCard(
            icon: Icons.email_outlined,
            iconBg: const Color(0xFFE6F1FB),
            iconColor: const Color(0xFF185FA5),
            title: 'Email Support',
            subtitle: _emailAddress,
            onTap: _openEmail,
          ),

          const SizedBox(height: 24),

          // ── FAQ section ────────────────────────────────────────────────────
          _sectionLabel('Frequently Asked Questions'),
          const SizedBox(height: 10),

          ..._faqs.asMap().entries.map((entry) {
            final idx = entry.key;
            final (q, a) = entry.value;
            final isOpen = _expandedFaq == idx;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => _expandedFaq = isOpen ? null : idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOpen ? _violet600 : _border,
                      width: isOpen ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _violet900.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isOpen ? _violet600 : _violet50,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(
                                isOpen
                                    ? Icons.remove_rounded
                                    : Icons.add_rounded,
                                size: 14,
                                color: isOpen ? Colors.white : _violet600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                q,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isOpen ? _violet600 : _textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isOpen) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(left: 34),
                            child: Text(
                              a,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    Color? badgeBg,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    splashColor: _violet100,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: _textSecondary.withValues(alpha: 0.5),
          ),
        ],
      ),
    ),
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
