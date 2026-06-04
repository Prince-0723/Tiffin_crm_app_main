import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../../customers/data/customer_api.dart';
import '../../../plans/data/plan_api.dart';
import '../../../plans/models/plan_model.dart';
import '../../../subscriptions/data/subscription_api.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../subscriptions/models/subscription_model.dart';
import '../../../../core/utils/subscription_calendar_days.dart';
import '../../../../models/customer_model.dart';

// ─── Purple Accent Pro palette ───────────────────────────────────────────────
class _AppPurple {
  static const v900 = Color(0xFF1E0A4A);
  static const v800 = Color(0xFF3B0FA0);
  static const v700 = Color(0xFF5B21B6);
  static const v600 = Color(0xFF7C3AED);
  static const v500 = Color(0xFF8B5CF6);
  static const v400 = Color(0xFFA78BFA);
  static const v300 = Color(0xFFC4B5FD);
  static const v200 = Color(0xFFDDD6FE);
  static const v100 = Color(0xFFEDE9FE);
  static const v50 = Color(0xFFF5F3FF);
  static const bg = Color(0xFFF0EBFF);

  static const green100 = Color(0xFFF0FDF4);
  static const green600 = Color(0xFF166534);
  static const green300 = Color(0xFF86EFAC);

  static const amber100 = Color(0xFFFFFBEB);
  static const amber600 = Color(0xFF92400E);
  static const amber300 = Color(0xFFFCD34D);

  static const red100 = Color(0xFFFEF2F2);
  static const red600 = Color(0xFF991B1B);
  static const red300 = Color(0xFFFCA5A5);

  static const gray100 = Color(0xFFF1F5F9);
  static const gray600 = Color(0xFF475569);
  static const gray300 = Color(0xFFCBD5E1);

  static const s900 = Color(0xFF0F172A);
  static const s700 = Color(0xFF334155);
  static const s600 = Color(0xFF475569);
  static const s500 = Color(0xFF64748B);
  static const s400 = Color(0xFF94A3B8);
  static const s200 = Color(0xFFE2E8F0);
  static const s100 = Color(0xFFF8FAFC);
}

// ─── Status helpers ──────────────────────────────────────────────────────────
_StatusStyle _statusStyle(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return _StatusStyle(
        bg: _AppPurple.green100,
        fg: _AppPurple.green600,
        border: _AppPurple.green300,
        accent: const Color(0xFF22C55E),
      );
    case 'paused':
      return _StatusStyle(
        bg: _AppPurple.amber100,
        fg: _AppPurple.amber600,
        border: _AppPurple.amber300,
        accent: const Color(0xFFF59E0B),
      );
    case 'expired':
      return _StatusStyle(
        bg: _AppPurple.red100,
        fg: _AppPurple.red600,
        border: _AppPurple.red300,
        accent: const Color(0xFFEF4444),
      );
    default:
      return _StatusStyle(
        bg: _AppPurple.gray100,
        fg: _AppPurple.gray600,
        border: _AppPurple.gray300,
        accent: _AppPurple.s400,
      );
  }
}

class _StatusStyle {
  final Color bg, fg, border, accent;
  const _StatusStyle({
    required this.bg,
    required this.fg,
    required this.border,
    required this.accent,
  });
}

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
}

// ─── Shared widgets ──────────────────────────────────────────────────────────
Widget _badge(String label, _StatusStyle style) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: style.bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: style.border, width: 0.5),
    ),
    child: Text(
      label[0].toUpperCase() + label.substring(1),
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: style.fg,
        letterSpacing: 0.3,
      ),
    ),
  );
}

Widget _avatarCircle(
  String initials, {
  double size = 38,
  Color? bg,
  Color? fg,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: bg ?? _AppPurple.v100,
      shape: BoxShape.circle,
      border: Border.all(color: _AppPurple.v200, width: 0.5),
    ),
    alignment: Alignment.center,
    child: Text(
      initials,
      style: TextStyle(
        fontSize: size * 0.3,
        fontWeight: FontWeight.w700,
        color: fg ?? _AppPurple.v700,
      ),
    ),
  );
}

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, this.initialPlan});
  final PlanModel? initialPlan;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  // ── all logic fields unchanged ──
  List<SubscriptionModel> _list = [];
  bool _loading = true;
  StreamSubscription<void>? _dailyOrdersSocketSub;
  static const List<String> _statusTabs = [
    'active',
    'paused',
    'expired',
    'cancelled',
  ];
  late TabController _tabController;
  String get _currentStatus => _statusTabs[_tabController.index];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
    _attachDailyOrdersSocket();
    final plan = widget.initialPlan;
    if (plan != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAssignSubscription(plan);
      });
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) _load();
  }

  @override
  void dispose() {
    _dailyOrdersSocketSub?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _attachDailyOrdersSocket() async {
    await DeliveryTrackingSocket.instance.ensureConnected();
    _dailyOrdersSocketSub =
        DeliveryTrackingSocket.instance.dailyOrdersRefresh.listen((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await SubscriptionApi.list(status: _currentStatus, limit: 50);
      final inner = res['data'];
      List<dynamic> rawList = [];
      if (inner is List) {
        rawList = inner;
      } else if (inner is Map<String, dynamic>) {
        rawList = (inner['data'] as List?) ?? [];
      }
      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => SubscriptionModel.fromJson(e))
          .toList();
      if (mounted) setState(() => _list = list);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDetail(SubscriptionModel sub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubscriptionDetailSheet(
        subscription: sub,
        onRenew: () async {
          final start = sub.endDate.isBefore(DateTime.now())
              ? DateTime.now()
              : sub.endDate;
          final end = DateTime(start.year, start.month + 1, start.day);
          try {
            await SubscriptionApi.renew(sub.id, start, end);
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            if (ctx.mounted) ErrorHandler.show(ctx, e);
          }
        },
        onViewCustomer: () {
          Navigator.pop(ctx);
          final c = CustomerModel(
            id: sub.customerId,
            name: sub.customerName ?? sub.customerId,
            phone: sub.customerPhone ?? '',
            email: null,
            address: sub.customerAddress,
            area: null,
            landmark: null,
            whatsapp: null,
            notes: null,
            tags: null,
            balance: null,
            walletBalance: null,
            location: null,
            vendorId: null,
            vendor: null,
            status: 'active',
            createdAt: null,
          );
          context.push(AppRoutes.customerDetail, extra: c);
        },
        onPause: () async {
          final now = DateTime.now();
          // ✅ Date picker se user choose kare
          final picked = await showDatePicker(
            context: ctx,
            initialDate: now.add(const Duration(days: 7)),
            firstDate: now,
            lastDate: now.add(const Duration(days: 365)),
            helpText: 'Pause until when?',
          );
          if (picked == null) return;
          try {
            await SubscriptionApi.pause(
              sub.id,
              pausedFrom: now,
              pausedUntil: picked,
            );
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            if (ctx.mounted) ErrorHandler.show(ctx, e);
          }
        },
        onUnpause: () async {
          try {
            await SubscriptionApi.unpause(sub.id);
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            if (ctx.mounted) ErrorHandler.show(ctx, e);
          }
        },
        // ✅ Cancel callback add karo
        onCancel: () async {
          final confirm = await showDialog<bool>(
            context: ctx,
            builder: (dCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Cancel Subscription',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              content: const Text(
                'Are you sure you want to cancel this subscription?',
                style: TextStyle(fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text(
                    'Yes, Cancel',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          if (confirm != true) return;
          try {
            await SubscriptionApi.cancel(sub.id);
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            if (ctx.mounted) ErrorHandler.show(ctx, e);
          }
        },
      ),
    );
  }

  void _openAssignSubscription([PlanModel? preselectedPlan]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignSubscriptionSheet(
        preselectedPlan: preselectedPlan,
        onCreated: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppPurple.bg,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Violet header ──
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFF7B3FE4)),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Subscriptions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_list.length} $_currentStatus plans',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Segmented tab bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _AppPurple.v200, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: _AppPurple.v300.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: _AppPurple.v600,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: _AppPurple.v600.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: _AppPurple.s500,
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: _statusTabs
                      .map(
                        (s) => Tab(
                          height: 32,
                          text: s[0].toUpperCase() + s.substring(1),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),

            // ── List body ──
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _AppPurple.v600,
                        strokeWidth: 2,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _AppPurple.v600,
                      child: _list.isEmpty
                          ? ListView(
                              padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).padding.bottom + 24,
                              ),
                              children: [
                                const SizedBox(height: 60),
                                Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: _AppPurple.v100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.assignment_outlined,
                                          color: _AppPurple.v500,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No $_currentStatus plan assignments',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _AppPurple.s500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              cacheExtent: 480,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                MediaQuery.of(context).padding.bottom + 100,
                              ),
                              itemCount: _list.length,
                              itemBuilder: (context, index) {
                                final sub = _list[index];
                                final totalDays = totalDaysInclusiveIST(
                                  sub.startDate,
                                  sub.endDate,
                                );
                                final daysRemaining = remainingDaysInclusiveIST(
                                  sub.startDate,
                                  sub.endDate,
                                );
                                final progress = totalDays > 0
                                    ? (1 - (daysRemaining / totalDays)).clamp(
                                        0.0,
                                        1.0,
                                      )
                                    : 1.0;
                                final st = _statusStyle(sub.status);
                                final planName = sub.planName ?? sub.planId;
                                final customerName =
                                    sub.customerName ?? sub.customerId;
                                final initials = _initials(customerName);

                                return RepaintBoundary(
                                  child: GestureDetector(
                                    onTap: () => _showDetail(sub),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _AppPurple.s200,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // ── Row 1: avatar + name + badge ──
                                            Row(
                                              children: [
                                                _avatarCircle(initials),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        customerName,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              _AppPurple.s900,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 1),
                                                      Text(
                                                        planName,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              _AppPurple.s500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                _badge(sub.status, st),
                                              ],
                                            ),

                                            const SizedBox(height: 10),
                                            const Divider(
                                              height: 1,
                                              thickness: 0.5,
                                              color: _AppPurple.s200,
                                            ),
                                            const SizedBox(height: 10),

                                            // ── Row 2: meta chips ──
                                            Row(
                                              children: [
                                                _metaChip(
                                                  Icons.calendar_today_outlined,
                                                  '${sub.startDate.day}/${sub.startDate.month}/${sub.startDate.year}',
                                                ),
                                                const SizedBox(width: 6),
                                                _metaChip(
                                                  Icons.event_outlined,
                                                  '${sub.endDate.day}/${sub.endDate.month}/${sub.endDate.year}',
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 10),

                                            // ── Progress bar ──
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 4,
                                                backgroundColor:
                                                    _AppPurple.v200,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(st.accent),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),

      // ── FAB ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAssignSubscription(),
        backgroundColor: _AppPurple.v600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Assign Plan',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _AppPurple.v50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _AppPurple.v200, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _AppPurple.v600),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _AppPurple.s700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DETAIL BOTTOM SHEET ──────────────────────────────────────────────────────
class _SubscriptionDetailSheet extends StatefulWidget {
  const _SubscriptionDetailSheet({
    required this.subscription,
    required this.onRenew,
    required this.onViewCustomer,
    required this.onPause,
    required this.onUnpause,
    required this.onCancel,
  });

  final SubscriptionModel subscription;
  final VoidCallback onRenew;
  final VoidCallback onViewCustomer;
  final VoidCallback onPause;
  final VoidCallback onUnpause;
  final VoidCallback onCancel;

  @override
  State<_SubscriptionDetailSheet> createState() =>
      _SubscriptionDetailSheetState();
}

class _SubscriptionDetailSheetState extends State<_SubscriptionDetailSheet> {
  late bool _autoRenew;
  bool _renewLoading = false;

  @override
  void initState() {
    super.initState();
    _autoRenew = widget.subscription.autoRenew;
  }

  // Future<void> _toggleAutoRenew() async {
  //   setState(() => _renewLoading = true);
  //   try {
  //     // Uses the renew endpoint to patch autoRenew field
  //     await DioClient.instance.put(
  //       '\${ApiEndpoints.subscriptions}/\${widget.subscription.id}',
  //       data: {'autoRenew': !_autoRenew},
  //     );
  //     setState(() => _autoRenew = !_autoRenew);
  //   } catch (e) {
  //     if (mounted) ErrorHandler.show(context, e);
  //   } finally {
  //     if (mounted) setState(() => _renewLoading = false);
  //   }
  // }
  Future<void> _toggleAutoRenew() async {
    setState(() => _renewLoading = true);
    try {
      await DioClient.instance.put(
        ApiEndpoints.subscriptionRenew(widget.subscription.id),
        data: {
          'startDate': widget.subscription.startDate
              .toIso8601String()
              .split('T')
              .first,
          'endDate': widget.subscription.endDate
              .toIso8601String()
              .split('T')
              .first,
          'autoRenew': !_autoRenew, // ✅ toggle value
        },
      );
      setState(() => _autoRenew = !_autoRenew);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _renewLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    final st = _statusStyle(sub.status);
    final customerName = sub.customerName ?? sub.customerId;
    final planName = sub.planName ?? sub.planId;
    final isEnded =
        sub.status.toLowerCase() == 'expired' ||
        sub.status.toLowerCase() == 'cancelled';
    final isActive = sub.status.toLowerCase() == 'active';
    final isPaused = sub.status.toLowerCase() == 'paused';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  24,
            ),
            children: [
              // ── Handle ──
              const BottomSheetHandle(),

              // ── Customer hero row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF7B3FE4), Color(0xFFA855F7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(customerName),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _AppPurple.s900,
                            ),
                          ),
                          if (sub.customerPhone != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              sub.customerPhone!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _AppPurple.s500,
                              ),
                            ),
                          ],
                          if (sub.customerAddress != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              sub.customerAddress!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _AppPurple.s500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _badge(sub.status, st),
                  ],
                ),
              ),

              // ── Plan info section label ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  'PLAN INFO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _AppPurple.v700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),

              // ── Plan info card ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: _AppPurple.s100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _AppPurple.s200, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Plan', planName),
                      if (sub.planType != null)
                        _infoRow('Plan type', sub.planType!),
                      _infoRow(
                        'Total Price',
                        sub.totalAmount != null
                            ? '₹${sub.totalAmount!.toStringAsFixed(0)}'
                            : '—',
                      ),
                      _infoRow('Status', sub.status),
                      if (sub.deliverySlot != null)
                        _infoRow('Delivery slot', sub.deliverySlot!),
                      if (sub.deliveryDays != null &&
                          sub.deliveryDays!.isNotEmpty)
                        _infoRow(
                          'Delivery days',
                          sub.deliveryDays!
                              .map(
                                (d) => [
                                  'Sun',
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                ][d],
                              )
                              .join(', '),
                        ),
                      _infoRow(
                        'Period',
                        '${sub.startDate.day}/${sub.startDate.month}/${sub.startDate.year} – ${sub.endDate.day}/${sub.endDate.month}/${sub.endDate.year}',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Auto renewal toggle row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: _AppPurple.s100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _AppPurple.s200, width: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Auto renewal',
                        style: TextStyle(fontSize: 12, color: _AppPurple.s500),
                      ),
                      const Spacer(),
                      if (_renewLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _AppPurple.v600,
                          ),
                        )
                      else
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _autoRenew,
                            onChanged: (_) => _toggleAutoRenew(),
                            activeColor: Colors.white,
                            activeTrackColor: _AppPurple.v600,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: _AppPurple.v300,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Action buttons ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: [
                    // View Customer + Extend Date
                    Row(
                      children: [
                        Expanded(
                          child: _outlineBtn(
                            'View Customer',
                            widget.onViewCustomer,
                          ),
                        ),
                        if (!isEnded) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _outlineBtn('Extend Date', widget.onRenew),
                          ),
                        ],
                      ],
                    ),
                    // Pause / Resume
                    if (isActive || isPaused) ...[
                      const SizedBox(height: 10),
                      _pauseBtn(
                        isPaused ? 'Resume Plan' : 'Pause Plan',
                        isPaused
                            ? const Color(0xFF166534)
                            : const Color(0xFF92400E),
                        isPaused
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFFFBEB),
                        isPaused
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCD34D),
                        isPaused ? widget.onUnpause : widget.onPause,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _pauseBtn(
                      'Cancel Subscription',
                      const Color(0xFF991B1B),
                      const Color(0xFFFEF2F2),
                      const Color(0xFFFCA5A5),
                      widget.onCancel,
                    ),
                    const SizedBox(height: 10),
                    _filledBtn('Close', () => Navigator.pop(context)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Info row ──
  Widget _infoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: _AppPurple.s200, width: 0.5),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _AppPurple.s500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? _AppPurple.s900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppPurple.v300, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _AppPurple.v700,
          ),
        ),
      ),
    );
  }

  Widget _pauseBtn(
    String label,
    Color fg,
    Color bg,

    Color border,

    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _filledBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _AppPurple.v600,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _AppPurple.v600.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'Close',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── ASSIGN SUBSCRIPTION SHEET ────────────────────────────────────────────────
class _AssignSubscriptionSheet extends StatefulWidget {
  const _AssignSubscriptionSheet({
    this.preselectedPlan,
    required this.onCreated,
  });
  final PlanModel? preselectedPlan;
  final VoidCallback onCreated;

  @override
  State<_AssignSubscriptionSheet> createState() =>
      _AssignSubscriptionSheetState();
}

class _AssignSubscriptionSheetState extends State<_AssignSubscriptionSheet> {
  // ── all logic fields unchanged ──
  CustomerModel? _customer;
  PlanModel? _plan;
  String? _selectedPlanId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  String _deliverySlot = 'morning';
  List<int> _deliveryDays = [1, 2, 3, 4, 5, 6];
  final _notesController = TextEditingController();
  final _creditLimitController = TextEditingController();
  bool _payLater = false;
  DateTime _paymentDueDate = DateTime.now().add(const Duration(days: 5));
  bool _loading = false;
  List<CustomerModel> _customers = [];
  List<PlanModel> _plans = [];

  static const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _plan = widget.preselectedPlan;
    _selectedPlanId = widget.preselectedPlan?.id;
    _loadCustomers();
    _loadPlans();
  }

  Future<void> _loadCustomers() async {
    try {
      final res = await CustomerApi.list(limit: 100, status: 'active');
      final rawList = (res['data'] as List?) ?? [];
      final customers = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => CustomerModel.fromJson(e))
          .toList();
      if (mounted) setState(() => _customers = customers);
    } catch (_) {}
  }

  Future<void> _loadPlans() async {
    try {
      final list = await PlanApi.list(limit: 50, isActive: true);
      if (mounted) {
        setState(() {
          _plans = list;
          if (list.isEmpty) {
            _selectedPlanId = null;
            _plan = null;
          } else {
            if (_plan != null && list.any((p) => p.id == _plan!.id)) {
              _selectedPlanId = _plan!.id;
            } else if (_plan == null) {
              _plan = list.first;
              _selectedPlanId = list.first.id;
            } else {
              _plan = null;
              _selectedPlanId = null;
            }
          }
        });
      }
    } catch (_) {}
  }

  void _toggleDay(int day) {
    setState(() {
      if (_deliveryDays.contains(day)) {
        _deliveryDays = _deliveryDays.where((d) => d != day).toList();
      } else {
        _deliveryDays = [..._deliveryDays, day]..sort();
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_customer == null || _plan == null) {
      AppSnackbar.error(context, 'Select customer and plan');
      return;
    }
    if (_deliveryDays.isEmpty) {
      AppSnackbar.error(context, 'Select at least one delivery day');
      return;
    }
    setState(() => _loading = true);
    try {
      final creditParsed = double.tryParse(
        _creditLimitController.text.trim(),
      );
      await SubscriptionApi.create({
        'customerId': _customer!.id,
        'planId': _plan!.id,
        'startDate': _startDate.toIso8601String().split('T').first,
        'endDate': _endDate.toIso8601String().split('T').first,
        'deliverySlot': _deliverySlot,
        'deliveryDays': _deliveryDays,
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
        'payLater': _payLater,
        if (_payLater) ...{
          'paymentDueDate':
              _paymentDueDate.toIso8601String().split('T').first,
          if (creditParsed != null && creditParsed > 0)
            'creditLimit': creditParsed,
        },
      });
      if (mounted) {
        AppSnackbar.success(context, 'Subscription created');
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── shared form field label ──
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: _AppPurple.v700,
        letterSpacing: 0.6,
      ),
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _AppPurple.s400, fontSize: 12),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _AppPurple.v300, width: 0.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _AppPurple.v500, width: 1),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).padding.bottom + 32,
            ),
            children: [
              const BottomSheetHandle(),
              const Text(
                'Assign Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _AppPurple.s900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 20),

              // ── Customer ──
              _label('Customer'),
              DropdownButtonFormField<CustomerModel>(
                value: _customer,
                decoration: _inputDeco('Select customer'),
                dropdownColor: Colors.white,
                style: const TextStyle(
                  fontSize: 12,
                  color: _AppPurple.s900,
                  fontWeight: FontWeight.w500,
                ),
                items: _customers
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.name} (${c.phone})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _customer = v),
              ),
              const SizedBox(height: 12),

              // ── Plan ──
              _label('Plan'),
              DropdownButtonFormField<String>(
                value: _plans.any((p) => p.id == _selectedPlanId)
                    ? _selectedPlanId
                    : null,
                decoration: _inputDeco('Select plan'),
                dropdownColor: Colors.white,
                style: const TextStyle(
                  fontSize: 12,
                  color: _AppPurple.s900,
                  fontWeight: FontWeight.w500,
                ),
                items: _plans
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(
                          '${p.planName} – ₹${p.price.toStringAsFixed(0)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _selectedPlanId = id;
                    _plan = _plans.firstWhere((p) => p.id == id);
                  });
                },
              ),
              const SizedBox(height: 12),

              // ── Dates row ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Start date'),
                        GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: _AppPurple.v600,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (d != null) setState(() => _startDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _AppPurple.v300,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _AppPurple.s900,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: _AppPurple.v500,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('End date'),
                        GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 2),
                              ),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: _AppPurple.v600,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (d != null) setState(() => _endDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _AppPurple.v300,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _AppPurple.s900,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: _AppPurple.v500,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Delivery slot ──
              _label('Delivery slot'),
              DropdownButtonFormField<String>(
                value: _deliverySlot,
                decoration: _inputDeco(''),
                dropdownColor: Colors.white,
                style: const TextStyle(
                  fontSize: 12,
                  color: _AppPurple.s900,
                  fontWeight: FontWeight.w500,
                ),
                items: ['morning', 'afternoon', 'evening']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s[0].toUpperCase() + s.substring(1)),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _deliverySlot = v ?? 'morning'),
              ),
              const SizedBox(height: 14),

              // ── Delivery days ──
              _label('Delivery days'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(7, (i) {
                  final selected = _deliveryDays.contains(i);
                  return GestureDetector(
                    onTap: () => _toggleDay(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _AppPurple.v600 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? _AppPurple.v600 : _AppPurple.v300,
                          width: 0.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: _AppPurple.v600.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        _dayLabels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _AppPurple.v600,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _AppPurple.v50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _AppPurple.v200, width: 0.5),
                ),
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  title: const Text(
                    'Start on credit (even if wallet is ₹0)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _AppPurple.s900,
                    ),
                  ),
                  subtitle: const Text(
                    'Meals use plan balance immediately. Wallet top-ups clear plan dues first.',
                    style: TextStyle(fontSize: 11, color: _AppPurple.s600),
                  ),
                  value: _payLater,
                  activeThumbColor: _AppPurple.v600,
                  onChanged: (v) => setState(() => _payLater = v),
                ),
              ),
              if (_payLater) ...[
                const SizedBox(height: 12),
                _label('Payment due by'),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _paymentDueDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: _AppPurple.v600,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) setState(() => _paymentDueDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _AppPurple.v300, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat.yMMMd().format(_paymentDueDate),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _AppPurple.s900,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: _AppPurple.v500,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _label(
                  'Credit limit (₹, optional)',
                ),
                TextField(
                  controller: _creditLimitController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 12, color: _AppPurple.s900),
                  decoration:
                      _inputDeco('Defaults to full plan price × days').copyWith(
                    helperText:
                        'Est. plan total ₹${((_plan?.price ?? 0) * totalDaysInclusiveIST(_startDate, _endDate)).toStringAsFixed(0)}',
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // ── Notes ──
              _label('Notes (optional)'),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(fontSize: 12, color: _AppPurple.s900),
                decoration: _inputDeco('Any special instructions…'),
              ),
              const SizedBox(height: 24),

              // ── Submit ──
              GestureDetector(
                onTap: _loading ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _loading ? _AppPurple.v400 : _AppPurple.v600,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _AppPurple.v600.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Assign Plan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
