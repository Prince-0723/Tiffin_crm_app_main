import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffin_crm/features/orders/models/order_model.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/location_helper.dart';
// ignore: unused_import
import '../../../../core/widgets/notification_bell_icon.dart';
import '../../../../models/customer_model.dart';
import '../../data/customer_portal_api.dart';
import '../../../dashboard/data/notification_api.dart';
import '../../../auth/data/auth_api.dart';
import '../../../orders/data/order_api.dart';
import '../../../orders/models/order_status.dart';

// ── iMeals Green + Violet palette ────────────────────────────────────────────
const _green900 = Color(0xFF064E3B);
const _green700 = Color(0xFF065F46);
const _green600 = Color(0xFF059669);
const _green200 = Color(0xFFA7F3D0);
const _green100 = Color(0xFFD1FAE5);
const _green50 = Color(0xFFF0FDF4);
const _violet700 = Color(0xFF4C2DB8);
const _violet600 = Color(0xFF5B35D5);
const _violet100 = Color(0xFFEDE8FD);
const _violet50 = Color(0xFFF5F2FF);
const _bg = Color(0xFFF9FFFE);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFD1FAE5);
const _divider = Color(0xFFE8FDF5);
const _text1 = Color(0xFF111827);
const _text2 = Color(0xFF6B7280);
const _warning = Color(0xFFBA7517);
const _warnSoft = Color(0xFFFAEEDA);
const _danger = Color(0xFFD93025);
const _dangerSoft = Color(0xFFFCECEB);

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  int _unreadCount = 0;
  String? _vendorUpiId;
  String _vendorPayLabel = 'vendor';

  // My Plan tab removed from shell — see commented block below (_CustomerMyPlanTab).
  static final List<Widget> _tabs = [
    RepaintBoundary(child: _CustomerHomeTab()),
    RepaintBoundary(child: _CustomerOrdersTab()),
    RepaintBoundary(child: _CustomerWalletTab()),
    RepaintBoundary(child: _CustomerProfileTab()),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _loadVendorUpiBanner();
  }

  Future<void> _loadVendorUpiBanner() async {
    try {
      final profile = await CustomerPortalApi.getMyProfile();
      final v = profile.vendor;
      final upi = v?.upiId?.trim() ?? '';
      if (!mounted) return;
      if (upi.isEmpty) {
        setState(() => _vendorUpiId = null);
      } else {
        final biz = v?.businessName?.trim() ?? '';
        final owner = v?.ownerName?.trim() ?? '';
        final label =
            biz.isNotEmpty ? biz : (owner.isNotEmpty ? owner : 'vendor');
        setState(() {
          _vendorUpiId = upi;
          _vendorPayLabel = label;
        });
      }
      await _maybeShowAnnouncementPopup(profile);
    } catch (_) {
      if (mounted) setState(() => _vendorUpiId = null);
    }
  }

  /// One-time dialog when vendor portal announcement text changes (per owner + updatedAt).
  Future<void> _maybeShowAnnouncementPopup(CustomerModel profile) async {
    final ownerId = profile.ownerId?.trim() ?? '';
    if (ownerId.isEmpty || !mounted) return;

    final text = profile.vendor?.announcementText?.trim() ?? '';
    if (text.isEmpty) return;

    final at = profile.vendor?.announcementUpdatedAt;
    if (at == null) return;

    final stamp = at.toUtc().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    final key = 'portal_ann_seen_$ownerId';
    if (prefs.getString(key) == stamp) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.campaign_rounded, color: _green700, size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Announcement',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _text1,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: _text1,
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: _green700,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await prefs.setString(key, stamp);
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final res = await NotificationApi.getMyNotifications();
      final list = (res['notifications'] as List?) ?? [];
      final unread = list.where((n) => n is Map && n['read'] == false).length;
      if (mounted) setState(() => _unreadCount = unread);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _text1,
        elevation: 0,
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _green100,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _border),
              ),
              child: const Center(
                child: Text(
                  'iM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _green700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'myMeals',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _text1,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () async {
                await context.push(AppRoutes.customerNotifications);
                if (mounted) _loadUnreadCount();
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _green50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      size: 20,
                      color: _green700,
                    ),
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD93025),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_vendorUpiId != null && _vendorUpiId!.isNotEmpty)
            _CustomerVendorUpiBanner(
              vendorLabel: _vendorPayLabel,
              upiId: _vendorUpiId!,
            ),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _tabs),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                  selected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Orders',
                  index: 1,
                  selected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _NavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet_rounded,
                  label: 'Wallet',
                  index: 2,
                  selected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  index: 3,
                  selected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Nav Item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final IconData icon, activeIcon;
  final String label;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 30,
            decoration: BoxDecoration(
              color: selected ? _violet100 : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              selected ? activeIcon : icon,
              size: 19,
              color: selected ? _violet600 : _text2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? _violet600 : _text2,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shown under the app bar on every customer tab when the vendor set a UPI ID.
class _CustomerVendorUpiBanner extends StatelessWidget {
  const _CustomerVendorUpiBanner({
    required this.vendorLabel,
    required this.upiId,
  });

  final String vendorLabel;
  final String upiId;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: upiId));
    if (!context.mounted) return;
    AppSnackbar.success(context, 'UPI ID copied');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _green50,
      child: InkWell(
        onTap: () => _copy(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: _green700, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pay $vendorLabel (UPI)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _text2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      upiId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _text1,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy_rounded, size: 20, color: _green600),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Tab
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerHomeTab extends StatefulWidget {
  const _CustomerHomeTab();
  @override
  State<_CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<_CustomerHomeTab> {
  OrderModel? _todayOrder;
  CustomerModel? _profile;
  CustomerBalanceModel? _balance;
  PublicPortalAnnouncement? _portalAnnouncement;
  /// Banner hidden until text changes (same session).
  String? _dismissedAnnouncementText;
  bool _loading = true;
  Timer? _refreshTimer;

  static final _announcementDateFmt = DateFormat('MMM d, h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        CustomerPortalApi.getTodayOrder(),
        CustomerPortalApi.getMyProfile(),
        CustomerPortalApi.getMyBalance(),
      ]);
      final order = results[0] as OrderModel?;
      final profile = results[1] as CustomerModel;
      final balance = results[2] as CustomerBalanceModel;
      final oid = profile.ownerId?.trim();
      final PublicPortalAnnouncement? announcement =
          (oid != null && oid.isNotEmpty)
              ? await CustomerPortalApi.getPublicPortalAnnouncement(oid)
              : null;
      if (mounted) {
        setState(() {
          _todayOrder = order;
          _profile = profile;
          _balance = balance;
          _portalAnnouncement = announcement;
        });
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _statusLabel(String status) =>
      OrderStatus.fromApi(status).label;

  static (Color, Color) _statusColors(String status) {
    final s = status.toLowerCase();
    if (s == 'delivered') return (_violet600, _violet50);
    if (s == 'out_for_delivery' || s == 'in_transit') {
      return (_violet600, _violet50);
    }
    if (s == 'processing' || s == 'cooking') return (_warning, _warnSoft);
    return (_text2, _divider);
  }

  // ── 30-day daily thoughts ────────────────────────────────────────────────
  static const _dailyThoughts = [
    (Icons.restaurant_rounded, 'Your taste is our responsibility'),
    (Icons.local_fire_department_rounded, 'Fresh, hot, delivered with love'),
    (Icons.favorite_outline_rounded, 'Eat well, live well, feel well'),
    (Icons.eco_rounded, 'Real food. Real ingredients. Real care'),
    (Icons.star_outline_rounded, 'Every meal crafted with purpose'),
    (Icons.lunch_dining_rounded, 'Good food is the foundation of happiness'),
    (Icons.timer_outlined, 'On time, every time — your tiffin awaits'),
    (Icons.spa_outlined, 'Nourish your body, fuel your day'),
    (Icons.rice_bowl_outlined, 'Homestyle food, delivered to your door'),
    (Icons.emoji_food_beverage_outlined, 'Taste the warmth in every bite'),
    (Icons.local_dining_rounded, 'Made with care, served with heart'),
    (Icons.health_and_safety_outlined, 'Wholesome meals for a wholesome you'),
    (Icons.access_time_rounded, 'Skip the kitchen, not the nutrition'),
    (Icons.thumb_up_outlined, 'Quality you can taste, service you can trust'),
    (Icons.people_outline_rounded, 'Feeding families, one tiffin at a time'),
    (Icons.kitchen_rounded, 'Just like home, only better'),
    (Icons.water_drop_outlined, 'Freshness guaranteed in every container'),
    (Icons.light_mode_outlined, 'Start your day right with a perfect meal'),
    (Icons.nights_stay_outlined, 'End your day with a satisfying dinner'),
    (Icons.breakfast_dining_rounded, 'Morning fuel prepared just for you'),
    (Icons.volunteer_activism_outlined, 'Every meal is a promise we keep'),
    (Icons.verified_outlined, 'Consistency is our secret ingredient'),
    (Icons.local_shipping_outlined, 'From our kitchen to your doorstep'),
    (Icons.forest_outlined, 'Natural ingredients, authentic flavors'),
    (Icons.groups_outlined, 'Connecting people through great food'),
    (Icons.wb_sunny_outlined, 'Sunshine on a plate, every single day'),
    (Icons.bolt_outlined, 'Power your day with the right nutrition'),
    (Icons.celebration_outlined, 'Every meal is worth celebrating'),
    (Icons.diversity_3_outlined, 'Diverse flavors, one great service'),
    (Icons.workspace_premium_outlined, 'Premium taste, everyday pricing'),
  ];

  (IconData, String) get _todaysThought {
    final idx = DateTime.now().day % _dailyThoughts.length;
    return _dailyThoughts[idx];
  }

  bool get _hasActivePortalAnnouncement =>
      (_portalAnnouncement?.text.trim().isNotEmpty ?? false);

  bool get _showAnnouncementBanner {
    final ann = _portalAnnouncement;
    if (ann == null) return false;
    final t = ann.text.trim();
    if (t.isEmpty) return false;
    return _dismissedAnnouncementText != t;
  }

  String _portalAnnouncementHeading(PublicPortalAnnouncement a) {
    final biz = a.businessName.trim();
    if (biz.isNotEmpty) return 'Announcement from $biz';
    final owner = a.ownerName.trim();
    if (owner.isNotEmpty) return 'Announcement from $owner';
    return 'Announcement from your vendor';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _todayOrder == null && _profile == null && _balance == null) {
      return const Center(child: CircularProgressIndicator(color: _green600));
    }
    final walletBalance = _balance?.walletBalance ?? _profile?.balance ?? 0.0;
    final subscriptionBalance = _balance?.subscriptionBalance ?? 0.0;
    final showNoChargeHint = _hasActivePortalAnnouncement;
    final lowBalance = walletBalance < 100;
    final firstName = (_profile?.name ?? 'there').split(' ').first;
    final (thoughtIcon, thoughtText) = _todaysThought;

    return RefreshIndicator(
      color: _green600,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        children: [
          if (_showAnnouncementBanner && _portalAnnouncement != null) ...[
            _portalAnnouncementBanner(_portalAnnouncement!),
            const SizedBox(height: 14),
          ],
          // ── Greeting ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $firstName!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Here's your tiffin update",
                      style: TextStyle(fontSize: 13, color: _text2),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _green100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Center(
                  child: Text(
                    (_profile?.name ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _green700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Daily thought card ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _violet50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _violet100),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _violet100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _violet100),
                  ),
                  child: Icon(thoughtIcon, size: 18, color: _violet600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    thoughtText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _violet700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Today's meal card ─────────────────────────────────────────────
          _sectionLabel("Today's Meal"),
          const SizedBox(height: 8),
          _todayOrder == null ? _emptyMealCard() : _mealCard(_todayOrder!),

          const SizedBox(height: 20),

          // ── Wallet card ───────────────────────────────────────────────────
          _sectionLabel('Wallet'),
          const SizedBox(height: 8),
          _walletCard(
            walletBalance,
            subscriptionBalance,
            showNoChargeHint: showNoChargeHint,
          ),

          // ── Low balance warning ───────────────────────────────────────────
          if (lowBalance && walletBalance >= 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _warnSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Low balance. Top up to avoid service interruption.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mealCard(OrderModel order) {
    final (statusColor, statusBg) = _statusColors(order.status);
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _green900.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: const BoxDecoration(
              color: _green600,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _green100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lunch_dining_rounded,
                    size: 22,
                    color: _green700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.slot ?? "Today's meal",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _text1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _statusLabel(order.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
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
    );
  }

  Widget _emptyMealCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _green50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: const Icon(
            Icons.lunch_dining_outlined,
            size: 22,
            color: _text2,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No order for today',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _text1,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Your tiffin will appear here once generated.',
                style: TextStyle(fontSize: 12, color: _text2),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _portalAnnouncementBanner(PublicPortalAnnouncement a) {
    final updated = a.updatedAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFC107).withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA000).withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECB3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Color(0xFFF57C00),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _portalAnnouncementHeading(a),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a.text.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: _text1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (updated != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Updated: ${_announcementDateFmt.format(updated.toLocal())}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _text2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _warnSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments_rounded, size: 15, color: _warning),
                          const SizedBox(width: 6),
                          const Text(
                            'No charge today',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _dismissedAnnouncementText = a.text.trim();
                  });
                },
                icon: const Icon(Icons.close_rounded, size: 20, color: _text2),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _walletCard(
    double walletBalance,
    double subscriptionBalance, {
    required bool showNoChargeHint,
  }) =>
      Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _violet100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 22,
            color: _violet600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rs.${walletBalance.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _violet700,
                ),
              ),
              const Text(
                'Available balance',
                style: TextStyle(fontSize: 12, color: _text2),
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    'Subscription: Rs.${subscriptionBalance.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _text2,
                    ),
                  ),
                  if (showNoChargeHint)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _warnSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        'No charge today',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _warning,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String text) => Row(
    children: [
      Container(
        width: 3,
        height: 13,
        decoration: BoxDecoration(
          color: _green600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _text2,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// My Plan Tab — HIDDEN (not in bottom nav / _tabs). Uncomment block + restore tab
// in _tabs and _NavItem "My Plan" (index 1) to show again.
// ─────────────────────────────────────────────────────────────────────────────
/*
class _CustomerMyPlanTab extends StatefulWidget {
  const _CustomerMyPlanTab();
  @override
  State<_CustomerMyPlanTab> createState() => _CustomerMyPlanTabState();
}

class _CustomerMyPlanTabState extends State<_CustomerMyPlanTab> {
  OrderModel? _todayOrder;
  List<_PlanItemRow> _items = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final order = await CustomerPortalApi.getTodayOrder();
      if (!mounted) return;
      _todayOrder = order;
      _items = _parseItems(order);
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_PlanItemRow> _parseItems(OrderModel? order) {
    if (order == null) return [];
    final list = <_PlanItemRow>[];
    final slots = order.mealSlots;
    if (slots == null) return [];
    for (final e in slots) {
      if (e is! Map<String, dynamic>) continue;
      final itemId = e['itemId']?.toString() ?? e['_id']?.toString() ?? '';
      final name = e['name']?.toString() ?? e['itemName']?.toString() ?? 'Item';
      final q = (e['quantity'] is num) ? (e['quantity'] as num).toInt() : 1;
      list.add(
        _PlanItemRow(itemId: itemId, name: name, quantity: q.clamp(1, 999)),
      );
    }
    return list;
  }

  Future<void> _save() async {
    if (_todayOrder == null || _items.isEmpty) return;
    setState(() => _saving = true);
    try {
      final quantities = _items
          .map((e) => {'itemId': e.itemId, 'quantity': e.quantity})
          .toList();
      await OrderApi.updateQuantities(_todayOrder!.id, quantities);
      if (mounted) AppSnackbar.success(context, 'Changes saved');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green600));
    }
    if (_todayOrder == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _green100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.restaurant_menu_outlined,
                size: 32,
                color: _green700,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No order for today',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _text1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your plan will appear here',
              style: TextStyle(fontSize: 13, color: _text2),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            children: [
              _sectionLabel('Your Plan'),
              const SizedBox(height: 4),
              const Text(
                'Adjust quantities (min 1). Tap Save to apply.',
                style: TextStyle(fontSize: 12, color: _text2),
              ),
              const SizedBox(height: 14),
              ..._items.map(
                (item) => _PlanItemStepper(
                  item: item,
                  onChanged: () => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: SizedBox(
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_violet700, _violet600],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: _violet600.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Row(
    children: [
      Container(
        width: 3,
        height: 13,
        decoration: BoxDecoration(
          color: _green600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _text2,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );
}

class _PlanItemRow {
  _PlanItemRow({
    required this.itemId,
    required this.name,
    required this.quantity,
  });
  final String itemId;
  final String name;
  int quantity;
}

class _PlanItemStepper extends StatelessWidget {
  const _PlanItemStepper({required this.item, required this.onChanged});
  final _PlanItemRow item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            item.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _text1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _green50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: item.quantity <= 1
                    ? null
                    : () {
                        item.quantity--;
                        onChanged();
                      },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.quantity <= 1 ? Colors.transparent : _green100,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.remove_rounded,
                    size: 16,
                    color: item.quantity <= 1 ? _text2 : _green700,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Center(
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _text1,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  item.quantity++;
                  onChanged();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _violet100,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: _violet600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
*/

// ─────────────────────────────────────────────────────────────────────────────
// Orders Tab
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerOrdersTab extends StatefulWidget {
  const _CustomerOrdersTab();
  @override
  State<_CustomerOrdersTab> createState() => _CustomerOrdersTabState();
}

class _CustomerOrdersTabState extends State<_CustomerOrdersTab> {
  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _statusFilter;
  Timer? _refreshTimer;

  static const List<String?> _statusValues = [
    null,
    'pending',
    'processing',
    'out_for_delivery',
    'delivered',
  ];
  static const List<String> _statusLabels = [
    'All',
    'Pending',
    'Processing',
    'Out for delivery',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _initLiveTrackingSocket();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load();
    });
  }

  Future<void> _initLiveTrackingSocket() async {
    final role = await SecureStorage.getUserRole();
    if (role == 'customer') {
      await DeliveryTrackingSocket.instance.ensureConnected();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await CustomerPortalApi.getMyOrders(
        page: 1,
        limit: 50,
        status: _statusFilter,
      );
      final orders = (res['orders'] as List<OrderModel>? ?? []);
      if (mounted) setState(() => _orders = orders);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOrderStatusSheet(OrderModel o) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _OrderStatusSheet(order: o),
    );
  }

  static (Color, Color, String) _statusMeta(String status) {
    final o = OrderStatus.fromApi(status);
    if (o == OrderStatus.delivered) {
      return (_violet600, _violet50, o.label);
    }
    if (o == OrderStatus.outForDelivery) {
      return (_violet600, _violet50, o.label);
    }
    if (o == OrderStatus.processing) {
      return (_warning, _warnSoft, o.label);
    }
    return (_text2, _divider, o.label);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          color: _surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).padding.bottom + 10,
            ),
            child: Row(
              children: List.generate(_statusLabels.length, (i) {
                final sel = _statusFilter == _statusValues[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _statusFilter = _statusValues[i]);
                      _load();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? _green700 : _green50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? _green700 : _border),
                      ),
                      child: Text(
                        _statusLabels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : _text2,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        Expanded(
          child: _loading && _orders.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _green600))
              : RefreshIndicator(
                  color: _green600,
                  onRefresh: _load,
                  child: _orders.isEmpty
                      ? ListView(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).padding.bottom + 24,
                          ),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: _green100,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 32,
                                      color: _green700,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'No orders yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _text1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            MediaQuery.of(context).padding.bottom + 32,
                          ),
                          itemCount: _orders.length,
                          itemBuilder: (ctx, i) {
                            final o = _orders[i];
                            final (sc, sb, sl) = _statusMeta(o.status);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () => _showOrderStatusSheet(o),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _green100,
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.lunch_dining_outlined,
                                          size: 20,
                                          color: _green700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              o.slot ?? 'Daily tiffin',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _text1,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${o.date.day.toString().padLeft(2, '0')}/'
                                              '${o.date.month.toString().padLeft(2, '0')}/'
                                              '${o.date.year}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: _text2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: sb,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: sc.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          sl,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: sc,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _OrderStatusSheet extends StatefulWidget {
  const _OrderStatusSheet({required this.order});
  final OrderModel order;

  @override
  State<_OrderStatusSheet> createState() => _OrderStatusSheetState();
}

class _OrderStatusSheetState extends State<_OrderStatusSheet> {
  StreamSubscription<DeliveryLocationUpdate>? _sub;
  DeliveryLocationUpdate? _live;
  DateTime? _liveAt;

  static const List<String> _steps = [
    'Order placed',
    'Processing',
    'Out for delivery',
    'Delivered',
  ];
  static const List<IconData> _icons = [
    Icons.shopping_bag_outlined,
    Icons.restaurant_outlined,
    Icons.delivery_dining_rounded,
    Icons.check_circle_outline_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    await DeliveryTrackingSocket.instance.ensureConnected();
    _sub = DeliveryTrackingSocket.instance.updates.listen((u) {
      if (!_matches(u) || !mounted) return;
      setState(() {
        _live = u;
        _liveAt = DateTime.now();
      });
    });
  }

  bool _matches(DeliveryLocationUpdate u) {
    final o = widget.order;
    if (u.orderId != null && u.orderId!.isNotEmpty) {
      return u.orderId == o.id;
    }
    if (u.customerIdForOrder != null && u.customerIdForOrder!.isNotEmpty) {
      return u.customerIdForOrder == o.customerId;
    }
    return false;
  }

  String _formatLiveAgo(DateTime t) {
    final sec = DateTime.now().difference(t).inSeconds;
    if (sec < 10) return 'just now';
    if (sec < 60) return '${sec}s ago';
    final m = sec ~/ 60;
    if (m < 60) return '${m}m ago';
    return '${m ~/ 60}h ago';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order.status.toLowerCase();
    int currentStep = 1;
    if (status == 'pending' || status == 'assigned') {
      currentStep = 1;
    } else if (status == 'processing' ||
        status == 'cooking' ||
        status == 'to_process')
      // ignore: curly_braces_in_flow_control_structures
      currentStep = 2;
    else if (status == 'out_for_delivery' || status == 'in_transit')
      // ignore: curly_braces_in_flow_control_structures
      currentStep = 3;
    else if (status == 'delivered')
      // ignore: curly_braces_in_flow_control_structures
      currentStep = 4;

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _green100,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: _green700,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Status',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _text1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(4, (i) {
            final done = (i + 1) <= currentStep;
            final active = (i + 1) == currentStep;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: done ? _green600 : _green50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: done ? _green600 : _border,
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      done ? Icons.check_rounded : _icons[i],
                      size: 17,
                      color: done ? Colors.white : _text2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _steps[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                      color: done ? _text1 : _text2,
                    ),
                  ),
                  if (active) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _violet100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Now',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _violet600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          if (status == 'out_for_delivery' || status == 'in_transit') ...[
            const SizedBox(height: 4),
            if (order.deliveryStaffName != null ||
                order.deliveryStaffPhone != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _green50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _green100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        size: 20,
                        color: _green700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.deliveryStaffName ?? 'Delivery partner',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _text1,
                            ),
                          ),
                          if (order.deliveryStaffPhone != null)
                            Text(
                              order.deliveryStaffPhone!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _text2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (order.deliveryStaffPhone?.isNotEmpty == true)
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse(
                            'tel:${order.deliveryStaffPhone!.replaceAll(RegExp(r'\D'), '')}',
                          ),
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _violet100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            size: 17,
                            color: _violet600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (_live != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _violet50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.radar_rounded, size: 20, color: _violet600),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Live rider location',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _text1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_liveAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 30),
                        child: Text(
                          'Updated ${_formatLiveAgo(_liveAt!)}',
                          style: const TextStyle(fontSize: 11, color: _text2),
                        ),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => LocationHelper.openInMaps(
                        _live!.lat,
                        _live!.lng,
                      ),
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: const Text(
                        'Open rider on map',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _violet600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _violet600,
                        side: BorderSide(
                          color: _violet600.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _text2),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallet Tab
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerWalletTab extends StatefulWidget {
  const _CustomerWalletTab();
  @override
  State<_CustomerWalletTab> createState() => _CustomerWalletTabState();
}

class _CustomerWalletTabState extends State<_CustomerWalletTab> {
  CustomerBalanceModel? _balance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final balance = await CustomerPortalApi.getMyBalance();
      if (mounted) setState(() => _balance = balance);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green600));
    }
    final walletBalance = _balance?.walletBalance ?? 0.0;
    final subscriptionBalance = _balance?.subscriptionBalance ?? 0.0;
    final lowBalance = walletBalance < 100;

    return RefreshIndicator(
      color: _green600,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        children: [
          _sectionLabel('Current Balance'),
          const SizedBox(height: 10),
          // Balance hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _green900.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _violet100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 26,
                    color: _violet600,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rs.${walletBalance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _violet700,
                      ),
                    ),
                    const Text(
                      'Available balance',
                      style: TextStyle(fontSize: 12, color: _text2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (lowBalance && walletBalance >= 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _warnSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Low balance. Please top up to continue service.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _sectionLabel('Subscription Balance'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
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
                    color: _green50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(
                    Icons.subscriptions_rounded,
                    size: 18,
                    color: _green700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rs.${subscriptionBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _text1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('Transaction History'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
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
                    color: _green50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(
                    Icons.receipt_outlined,
                    size: 18,
                    color: _text2,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'No transactions yet.',
                  style: TextStyle(fontSize: 13, color: _text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Row(
    children: [
      Container(
        width: 3,
        height: 13,
        decoration: BoxDecoration(
          color: _green600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _text2,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Tab
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerProfileTab extends StatefulWidget {
  const _CustomerProfileTab();
  @override
  State<_CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<_CustomerProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  CustomerModel? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await CustomerPortalApi.getMyProfile();
      if (mounted) {
        _profile = profile;
        _nameCtrl.text = profile.name;
        _addressCtrl.text = profile.address ?? '';
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.show(context, e);
        setState(() => _loading = false);
      }
    }
  }

  // ignore: unused_element
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await CustomerPortalApi.updateMyProfile({
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      });
      if (mounted) AppSnackbar.success(context, 'Profile updated');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      // ignore: empty_statements
      if (mounted) ;
    }
  }

  Future<void> _shareLocation() async {
    final position = await LocationHelper.getCurrentPosition();
    if (position == null || !mounted) return;
    try {
      await CustomerPortalApi.updateMyProfile({
        'location': {
          'type': 'Point',
          'coordinates': [position.longitude, position.latitude],
        },
      });
      if (mounted) AppSnackbar.success(context, 'Location shared with vendor');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<void> _logout() async {
    try {
      await AuthApi.logout();
    } catch (_) {}
    await AuthSession.clearLocalSession();
    if (!mounted) return;
    context.go(AppRoutes.roleSelection);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green600));
    }
    final initial = (_profile?.name ?? '?')[0].toUpperCase();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.of(context).padding.bottom + 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Identity card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _green900.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _green100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _green700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile?.name ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _text1,
                        ),
                      ),
                      if (_profile?.phone != null)
                        Text(
                          _profile!.phone,
                          style: const TextStyle(fontSize: 12, color: _text2),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Share location ─────────────────────────────────────────────────
          InkWell(
            onTap: _shareLocation,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: _green50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _green100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _green200),
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      size: 18,
                      color: _green700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Location with Vendor',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _green900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Help us deliver faster to your door',
                          style: TextStyle(fontSize: 11, color: _text2),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _text2,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Logout ─────────────────────────────────────────────────────────
          InkWell(
            onTap: _logout,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: _dangerSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _danger.withValues(alpha: 0.22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, size: 16, color: _danger),
                  const SizedBox(width: 8),
                  const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _greenField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    int maxLines = 1,
  }) => TextFormField(
    controller: ctrl,
    validator: validator,
    maxLines: maxLines,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: _text1,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: _text2),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, size: 18, color: _green700),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: _green50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _green600, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _danger, width: 1.5),
      ),
    ),
  );

  // ignore: unused_element
  Widget _sectionLabel(String text) => Row(
    children: [
      Container(
        width: 3,
        height: 13,
        decoration: BoxDecoration(
          color: _green600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _text2,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );
}
