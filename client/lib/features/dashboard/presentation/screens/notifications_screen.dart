// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
// ignore: unused_import
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../models/notification_model.dart';
import '../../data/notification_api.dart';
import '../../../../core/notifications/notification_badge_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  // ─── ALL FUNCTIONALITY UNCHANGED ───────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await NotificationApi.getMyNotifications();
      if (mounted) {
        setState(() {
          _notifications =
              (res['notifications'] as List<NotificationModel>?) ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ErrorHandler.show(context, e);
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationApi.markAllRead();
      await NotificationBadgeService.refreshNow();
    } catch (_) {}
  }

  Future<void> _delete(NotificationModel n) async {
    try {
      await NotificationApi.deleteNotification(n.id);
      if (mounted) {
        setState(() {
          _notifications = _notifications.where((e) => e.id != n.id).toList();
        });
      }
      await NotificationBadgeService.refreshNow();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<void> _clearRead() async {
    try {
      await NotificationApi.clearReadNotifications();
      await _load();
      await NotificationBadgeService.refreshNow();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (n.read) return;
    try {
      await NotificationApi.markNotificationRead(n.id);
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map(
                (e) => e.id == n.id
                    ? NotificationModel(
                        id: e.id,
                        title: e.title,
                        body: e.body,
                        time: e.time,
                        read: true,
                        type: e.type,
                      )
                    : e,
              )
              .toList();
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
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  String _stripEmojis(String text) {
    return text
        .replaceAll(
          RegExp(
            r'[\u{1F600}-\u{1F64F}'
            r'\u{1F300}-\u{1F5FF}'
            r'\u{1F680}-\u{1F6FF}'
            r'\u{1F700}-\u{1F77F}'
            r'\u{1F780}-\u{1F7FF}'
            r'\u{1F800}-\u{1F8FF}'
            r'\u{1F900}-\u{1F9FF}'
            r'\u{1FA00}-\u{1FA6F}'
            r'\u{1FA70}-\u{1FAFF}'
            r'\u{2600}-\u{26FF}'
            r'\u{2700}-\u{27BF}'
            r'\u{FE00}-\u{FE0F}'
            r'\u{1F1E0}-\u{1F1FF}'
            r'\u{200D}'
            r'\u{20E3}]',
            unicode: true,
          ),
          '',
        )
        .trim();
  }

  String _groupLabel(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return 'Just Now';
    if (diff.inHours < 24) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} Days Ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  List<_NotifGroup> _buildGroups() {
    final Map<String, List<NotificationModel>> map = {};
    final List<String> order = [];
    for (final n in _notifications) {
      final label = _groupLabel(n.time);
      if (!map.containsKey(label)) {
        map[label] = [];
        order.add(label);
      }
      map[label]!.add(n);
    }
    return order.map((l) => _NotifGroup(label: l, items: map[l]!)).toList();
  }

  _NotifStyle _styleForType(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'out_for_delivery':
        return _NotifStyle(
          label: 'Out for Delivery',
          pillBg: const Color(0xFFFFF0DC),
          pillText: const Color(0xFF7D4500),
          iconBg: const Color(0xFFFFF0DC),
          iconColor: const Color(0xFFBA7517),
          dotColor: const Color(0xFFBA7517),
          icon: Icons.delivery_dining_rounded,
        );
      case 'delivered':
        return _NotifStyle(
          label: 'Delivered',
          pillBg: const Color(0xFFE6F4D7),
          pillText: const Color(0xFF2D6A0A),
          iconBg: const Color(0xFFE6F4D7),
          iconColor: const Color(0xFF3B8C12),
          dotColor: const Color(0xFF3B8C12),
          icon: Icons.check_circle_outline_rounded,
        );
      case 'task_accepted':
        return _NotifStyle(
          label: 'Task Accepted',
          pillBg: const Color(0xFFEEEDFE),
          pillText: const Color(0xFF4A3FA5),
          iconBg: const Color(0xFFEEEDFE),
          iconColor: const Color(0xFF534AB7),
          dotColor: const Color(0xFF7F77DD),
          icon: Icons.handshake_outlined,
        );
      case 'order_processing':
        return _NotifStyle(
          label: 'Preparing',
          pillBg: const Color(0xFFFFF8E1),
          pillText: const Color(0xFF6B4C00),
          iconBg: const Color(0xFFFFF8E1),
          iconColor: const Color(0xFFD4A017),
          dotColor: const Color(0xFFD4A017),
          icon: Icons.restaurant_outlined,
        );
      case 'order_placed':
        return _NotifStyle(
          label: 'Order Placed',
          pillBg: const Color(0xFFEEEDFE),
          pillText: const Color(0xFF4A3FA5),
          iconBg: const Color(0xFFEEEDFE),
          iconColor: const Color(0xFF534AB7),
          dotColor: const Color(0xFF7F77DD),
          icon: Icons.shopping_bag_outlined,
        );
      case 'payment':
      case 'wallet':
        return _NotifStyle(
          label: 'Payment',
          pillBg: const Color(0xFFE6F4D7),
          pillText: const Color(0xFF2D6A0A),
          iconBg: const Color(0xFFE6F4D7),
          iconColor: const Color(0xFF3B8C12),
          dotColor: const Color(0xFF3B8C12),
          icon: Icons.account_balance_wallet_outlined,
        );
      case 'cancelled':
        return _NotifStyle(
          label: 'Cancelled',
          pillBg: const Color(0xFFFCEBEB),
          pillText: const Color(0xFF8C2020),
          iconBg: const Color(0xFFFCEBEB),
          iconColor: const Color(0xFFC0392B),
          dotColor: const Color(0xFFC0392B),
          icon: Icons.cancel_outlined,
        );
      case 'system':
      case 'alert':
        return _NotifStyle(
          label: 'Alert',
          pillBg: const Color(0xFFFCEBEB),
          pillText: const Color(0xFF8C2020),
          iconBg: const Color(0xFFFCEBEB),
          iconColor: const Color(0xFFC0392B),
          dotColor: const Color(0xFFC0392B),
          icon: Icons.warning_amber_rounded,
        );
      default:
        return _NotifStyle(
          label: 'Notification',
          pillBg: const Color(0xFFF0EFFF),
          pillText: const Color(0xFF534AB7),
          iconBg: const Color(0xFFF0EFFF),
          iconColor: const Color(0xFF7F77DD),
          dotColor: const Color(0xFF7F77DD),
          icon: Icons.notifications_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.read).length;
    final hasRead = _notifications.any((n) => n.read);

    return Scaffold(
      backgroundColor: const Color(0xFFE8E6F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B21D4),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          if (hasRead)
            IconButton(
              onPressed: _clearRead,
              tooltip: 'Clear all read',
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Color(0xFFFF4444),
                size: 26,
              ),
            ),
        ],
      ),
      body: _loading && _notifications.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B21D4)),
            )
          : RefreshIndicator(
              color: const Color(0xFF6B21D4),
              onRefresh: _load,
              child: _notifications.isEmpty ? _buildEmptyState() : _buildList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEDFE),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: Color(0xFF6B21D4),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'No notifications yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Updates and alerts will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
        ),
      ],
    );
  }

  Widget _buildList() {
    final groups = _buildGroups();
    return ListView.builder(
      cacheExtent: 400,
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      itemCount: groups.length,
      itemBuilder: (context, gi) {
        final group = groups[gi];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 16, bottom: 8),
              child: Text(
                group.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF888888),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(
                  group.items.length,
                  (ii) => _buildTimelineRow(
                    group.items[ii],
                    ii == group.items.length - 1,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineRow(NotificationModel n, bool isLast) {
    final style = _styleForType(n.type);
    final isRead = n.read;

    final cleanTitle = _stripEmojis(n.title);
    final cleanBody = _stripEmojis(n.body);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 22,
            child: Stack(
              children: [
                if (!isLast)
                  Positioned(
                    top: 20,
                    bottom: 0,
                    left: 10,
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFCCCCCC),
                    ),
                  ),
                Positioned(
                  top: 10,
                  left: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // ✅ dot always full color, no fade
                      color: style.dotColor,
                      border: Border.all(
                        color: const Color(0xFFE8E6F0),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Card
          Expanded(
            child: GestureDetector(
              onTap: () => _markRead(n),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
                decoration: BoxDecoration(
                  // ✅ read = slightly off-white, unread = white — no big difference
                  color: isRead ? const Color(0xFFF8F8F8) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isRead ? const Color(0xFFEEEEEE) : style.pillBg,
                    width: isRead ? 1.0 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Icon always full color, no fade
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: style.iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(style.icon, size: 22, color: style.iconColor),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ Pill always full color, no fade
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: style.pillBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              style.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: style.pillText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),

                          // ✅ Title: bold when unread, normal (w400) when read — NO color fade
                          Text(
                            cleanTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isRead
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              // ✅ same dark color always
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 3),

                          // ✅ Body: same color always, no fade
                          Text(
                            cleanBody,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(n.time),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFBBBBBB),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _delete(n),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Color(0xFFBBBBBB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DATA CLASSES ──────────────────────────────────────────────────────────────

class _NotifGroup {
  final String label;
  final List<NotificationModel> items;
  const _NotifGroup({required this.label, required this.items});
}

class _NotifStyle {
  final String label;
  final Color pillBg;
  final Color pillText;
  final Color iconBg;
  final Color iconColor;
  final Color dotColor;
  final IconData icon;

  const _NotifStyle({
    required this.label,
    required this.pillBg,
    required this.pillText,
    required this.iconBg,
    required this.iconColor,
    required this.dotColor,
    required this.icon,
  });
}
