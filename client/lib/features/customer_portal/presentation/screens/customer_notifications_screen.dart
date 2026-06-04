import 'package:flutter/material.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../models/notification_model.dart';
import '../../data/customer_portal_api.dart';
import '../../../../core/notifications/notification_badge_service.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  // ── iMeals Green + Violet palette ─────────────────────────────────────────
  static const _green900  = Color(0xFF064E3B);
  static const _green700  = Color(0xFF065F46);
  static const _green600  = Color(0xFF059669);
  static const _green100  = Color(0xFFD1FAE5);
  static const _green50   = Color(0xFFF0FDF4);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet100 = Color(0xFFEDE8FD);
  // ignore: unused_field
  static const _violet50  = Color(0xFFF5F2FF);
  static const _bg        = Color(0xFFF9FFFE);
  static const _surface   = Color(0xFFFFFFFF);
  static const _border    = Color(0xFFD1FAE5);
  // ignore: unused_field
  static const _divider   = Color(0xFFE8FDF5);
  static const _text1     = Color(0xFF111827);
  static const _text2     = Color(0xFF6B7280);
  // ignore: unused_field
  static const _danger    = Color(0xFFD93025);
  static const _warning   = Color(0xFFBA7517);
  static const _warnSoft  = Color(0xFFFAEEDA);

  // ── State ──────────────────────────────────────────────────────────────────
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  // ── API (unchanged) ────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await CustomerPortalApi.getMyNotifications();
      if (mounted) {
        setState(() {
          final raw =
              (res['notifications'] as List<NotificationModel>?) ?? [];
          _notifications = _dedupeVendorAnnouncements(raw);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) { setState(() => _loading = false); ErrorHandler.show(context, e); }
    }
  }

  /// Collapses duplicate vendor broadcast rows (same title+body), keeps first (newest from API order).
  static List<NotificationModel> _dedupeVendorAnnouncements(
    List<NotificationModel> list,
  ) {
    final seen = <String>{};
    final out = <NotificationModel>[];
    for (final n in list) {
      final t = (n.type ?? '').toLowerCase();
      if (t == 'vendor_announcement') {
        final key = '${n.title}|${n.body}';
        if (seen.contains(key)) continue;
        seen.add(key);
      }
      out.add(n);
    }
    return out;
  }

  Future<void> _markAllRead() async {
    try {
      await CustomerPortalApi.markAllNotificationsRead();
      await NotificationBadgeService.refreshNow();
    } catch (_) {}
  }

  Future<void> _delete(NotificationModel n) async {
    try {
      await CustomerPortalApi.deleteNotification(n.id);
      // ignore: curly_braces_in_flow_control_structures
      if (mounted) setState(() =>
          _notifications = _notifications.where((e) => e.id != n.id).toList());
      await NotificationBadgeService.refreshNow();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<void> _clearRead() async {
    try {
      await CustomerPortalApi.clearReadNotifications();
      await _load();
      await NotificationBadgeService.refreshNow();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (n.read) return;
    try {
      await CustomerPortalApi.markNotificationRead(n.id);
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((e) => e.id == n.id
              ? NotificationModel(id: e.id, title: e.title, body: e.body,
                  time: e.time, read: true, type: e.type)
              : e).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _markAllRead();
    _load();
  }

  String _formatTime(DateTime t) {
    final now  = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  String _stripEmojis(String text) => text.replaceAll(RegExp(
    r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}'
    r'\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}'
    r'\u{1F900}-\u{1F9FF}\u{200D}\u{20E3}]',
    unicode: true), '').trim();

  // ── Type styling ───────────────────────────────────────────────────────────
  _NotifStyle _styleForType(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'out_for_delivery':
        return _NotifStyle(label: 'Out for Delivery',
          pillBg: _warnSoft, pillText: _warning,
          iconBg: _warnSoft, iconColor: _warning,
          dotColor: _warning, icon: Icons.delivery_dining_rounded);
      case 'delivered':
        return _NotifStyle(label: 'Delivered',
          pillBg: _violet100, pillText: _violet600,
          iconBg: _violet100, iconColor: _violet600,
          dotColor: _violet600, icon: Icons.check_circle_outline_rounded);
      case 'order_processing':
        return _NotifStyle(label: 'Preparing',
          pillBg: const Color(0xFFFFF8E1), pillText: const Color(0xFF6B4C00),
          iconBg: const Color(0xFFFFF8E1), iconColor: const Color(0xFFD4A017),
          dotColor: const Color(0xFFD4A017), icon: Icons.restaurant_outlined);
      case 'order_placed':
        return _NotifStyle(label: 'Order Placed',
          pillBg: _green100, pillText: _green700,
          iconBg: _green100, iconColor: _green700,
          dotColor: _green600, icon: Icons.shopping_bag_outlined);
      case 'payment': case 'wallet':
        return _NotifStyle(label: 'Payment',
          pillBg: _green100, pillText: _green700,
          iconBg: _green100, iconColor: _green700,
          dotColor: _green600, icon: Icons.account_balance_wallet_outlined);
      case 'cancelled':
        return _NotifStyle(label: 'Cancelled',
          pillBg: const Color(0xFFFCEBEB), pillText: const Color(0xFF8C2020),
          iconBg: const Color(0xFFFCEBEB), iconColor: const Color(0xFFC0392B),
          dotColor: const Color(0xFFC0392B), icon: Icons.cancel_outlined);
      case 'system': case 'alert':
        return _NotifStyle(label: 'Alert',
          pillBg: const Color(0xFFFCEBEB), pillText: const Color(0xFF8C2020),
          iconBg: const Color(0xFFFCEBEB), iconColor: const Color(0xFFC0392B),
          dotColor: const Color(0xFFC0392B), icon: Icons.warning_amber_rounded);
      case 'vendor_announcement':
        return _NotifStyle(
          label: 'Announcement',
          pillBg: _violet100,
          pillText: _violet600,
          iconBg: _violet100,
          iconColor: _violet600,
          dotColor: _violet600,
          icon: Icons.campaign_rounded,
        );
      default:
        return _NotifStyle(label: 'Notification',
          pillBg: _green50, pillText: _green700,
          iconBg: _green50, iconColor: _green700,
          dotColor: _green600, icon: Icons.notifications_outlined);
    }
  }

  // ── Group helpers ──────────────────────────────────────────────────────────
  String _groupLabel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return 'Just Now';
    if (diff.inHours < 24)   return 'Today';
    if (diff.inDays == 1)    return 'Yesterday';
    if (diff.inDays < 7)     return '${diff.inDays} Days Ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  List<_NotifGroup> _buildGroups() {
    final map   = <String, List<NotificationModel>>{};
    final order = <String>[];
    for (final n in _notifications) {
      final label = _groupLabel(n.time);
      if (!map.containsKey(label)) { map[label] = []; order.add(label); }
      map[label]!.add(n);
    }
    return order.map((l) => _NotifGroup(label: l, items: map[l]!)).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.read).length;
    final hasRead     = _notifications.any((n) => n.read);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop()),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Notifications',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 0.2)),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20)),
              child: Text('$unreadCount',
                style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: Colors.white))),
          ],
        ]),
        actions: [
          if (hasRead)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: Colors.white70, size: 24),
              tooltip: 'Clear all read',
              onPressed: _clearRead),
        ],
      ),
      body: _loading && _notifications.isEmpty
          ? Center(child: CircularProgressIndicator(
              color: _green600, strokeWidth: 2.5))
          : RefreshIndicator(
              color: _green600,
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
            ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty() => ListView(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.of(context).padding.bottom + 24,
    ),
    children: [
      const SizedBox(height: 80),
      Center(child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: _green100, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.notifications_none_rounded,
            size: 36, color: _green700))),
      const SizedBox(height: 16),
      const Text('No notifications yet',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
            color: _text1)),
      const SizedBox(height: 6),
      const Text('Meal updates and alerts will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: _text2)),
    ],
  );

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList() {
    final groups = _buildGroups();
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      itemCount: groups.length,
      itemBuilder: (context, gi) {
        final group = groups[gi];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 14, bottom: 6),
            child: Text(group.label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: _text2, letterSpacing: 1.0))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: List.generate(group.items.length, (ii) =>
              _buildRow(group.items[ii], ii == group.items.length - 1)))),
        ]);
      },
    );
  }

  // ── Notification row ───────────────────────────────────────────────────────
  Widget _buildRow(NotificationModel n, bool isLast) {
    final style      = _styleForType(n.type);
    final isRead     = n.read;
    final cleanTitle = _stripEmojis(n.title);
    final cleanBody  = _stripEmojis(n.body);

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Timeline
        SizedBox(width: 22, child: Stack(children: [
          if (!isLast)
            Positioned(top: 20, bottom: 0, left: 10,
              child: Container(width: 1.5,
                  color: _border)),
          Positioned(top: 10, left: 6,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: style.dotColor,
                border: Border.all(color: _bg, width: 2)))),
        ])),
        const SizedBox(width: 8),

        // Card
        Expanded(
          child: GestureDetector(
            onTap: () => _markRead(n),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
              decoration: BoxDecoration(
                color: isRead ? const Color(0xFFF8FFFE) : _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRead ? _border : style.pillBg,
                  width: isRead ? 1.0 : 1.5),
                boxShadow: [BoxShadow(
                  color: _green900.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2))]),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Icon
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: style.iconBg,
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(style.icon, size: 20, color: style.iconColor)),
                const SizedBox(width: 10),

                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: style.pillBg,
                        borderRadius: BorderRadius.circular(10)),
                      child: Text(style.label,
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: style.pillText))),
                    const SizedBox(height: 5),
                    // Title
                    Text(cleanTitle, style: TextStyle(
                      fontSize: 13,
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                      color: _text1)),
                    const SizedBox(height: 3),
                    // Body
                    Text(cleanBody, style: const TextStyle(
                      fontSize: 12, color: _text2, height: 1.4)),
                  ])),

                const SizedBox(width: 6),
                // Time + delete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatTime(n.time),
                      style: const TextStyle(fontSize: 10, color: _text2)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _delete(n),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline_rounded,
                          size: 15, color: _text2.withValues(alpha: 0.5)))),
                  ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Data classes ───────────────────────────────────────────────────────────────

class _NotifGroup {
  final String label;
  final List<NotificationModel> items;
  const _NotifGroup({required this.label, required this.items});
}

class _NotifStyle {
  final String   label;
  final Color    pillBg, pillText, iconBg, iconColor, dotColor;
  final IconData icon;
  const _NotifStyle({
    required this.label, required this.pillBg, required this.pillText,
    required this.iconBg, required this.iconColor, required this.dotColor,
    required this.icon,
  });
}