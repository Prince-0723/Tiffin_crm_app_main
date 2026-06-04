import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import '../../overview_dashboard_refresh_signal.dart';
import '../../../customers/data/customer_api.dart';
import '../../../delivery/data/delivery_api.dart';
import '../../data/daily_items_api.dart';
import '../../../orders/data/order_api.dart';
import '../../../orders/models/order_status.dart';

/// Fixed width for each status pill in the horizontal “today’s orders” strip.
const double _kTodayOrdersTileWidth = 118;

/// Height of the strip (tiles + room for scrollbar inside the card).
const double _kTodayOrdersStripHeight = 128;

enum _DailyItemsChip { all, veg, nonVeg }

enum _MealSlot { all, breakfast, lunch, dinner }

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key, this.adminName = 'Vendor'});
  final String adminName;

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  bool _loading = true;
  int _customersCount = 0;
  int _ordersCount = 0;
  int _ordersPendingCount = 0;
  int _ordersProcessingCount = 0;
  int _ordersOutForDeliveryCount = 0;
  int _ordersDeliveredCount = 0;
  int _ordersCancelledCount = 0;
  int _deliveryStaffCount = 0;

  bool _itemsListLoading = true;
  Object? _itemsError;
  List<DailyItemRow> _dailyItems = [];
  int? _dailyItemsCustomerCount;
  StreamSubscription<void>? _dailyOrdersSocketSub;
  VoidCallback? _overviewTabReselectedListener;
  /// Calendar day for daily-items API (local). Initialized in [initState] for web safety.
  late DateTime _itemsDay;
  _DailyItemsChip _itemsChip = _DailyItemsChip.all;
  _MealSlot _mealSlot = _MealSlot.all;

  final ScrollController _todayOrdersStripController = ScrollController();

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static String _todayDate() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _itemsDay = DateTime(n.year, n.month, n.day);
    _loadStats();
    _loadDailyItems();
    _attachDailyOrdersSocket();
    _overviewTabReselectedListener = () {
      if (!mounted) return;
      _loadStats();
      _loadDailyItems();
    };
    overviewDashboardTabSelectedTick.addListener(_overviewTabReselectedListener!);
  }

  Future<void> _attachDailyOrdersSocket() async {
    await DeliveryTrackingSocket.instance.ensureConnected();
    _dailyOrdersSocketSub =
        DeliveryTrackingSocket.instance.dailyOrdersRefresh.listen((_) {
      if (mounted) {
        _loadStats();
        _loadDailyItems();
      }
    });
  }

  @override
  void dispose() {
    if (_overviewTabReselectedListener != null) {
      overviewDashboardTabSelectedTick
          .removeListener(_overviewTabReselectedListener!);
    }
    _dailyOrdersSocketSub?.cancel();
    _todayOrdersStripController.dispose();
    super.dispose();
  }

  static String? _mealSlotQueryParam(_MealSlot slot) {
    switch (slot) {
      case _MealSlot.all:
        return null;
      case _MealSlot.breakfast:
        return 'breakfast';
      case _MealSlot.lunch:
        return 'lunch';
      case _MealSlot.dinner:
        return 'dinner';
    }
  }

  Future<void> _loadDailyItems() async {
    if (!mounted) return;
    setState(() {
      _itemsListLoading = true;
      _itemsError = null;
    });
    try {
      final d = DateTime(_itemsDay.year, _itemsDay.month, _itemsDay.day);
      final result = await DailyItemsApi.fetch(
        forDay: d,
        slot: _mealSlotQueryParam(_mealSlot),
      );
      if (!mounted) return;
      setState(() {
        _dailyItems = result.items;
        _dailyItemsCustomerCount = result.customerCount;
        _itemsListLoading = false;
        _itemsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _itemsError = e;
        _itemsListLoading = false;
      });
    }
  }

  Future<void> _onMealSlotSelected(_MealSlot slot) async {
    if (_mealSlot == slot || _itemsListLoading) return;
    setState(() => _mealSlot = slot);
    await Future.wait<void>([
      _loadDailyItems(),
      _loadStats(),
    ]);
  }

  String _itemsPrepareTitle() {
    final suffix = switch (_mealSlot) {
      _MealSlot.all => '',
      _MealSlot.breakfast => ' — Breakfast',
      _MealSlot.lunch => ' — Lunch',
      _MealSlot.dinner => ' — Dinner',
    };
    return 'Items to Prepare$suffix';
  }

  String _slotChipLabel(_MealSlot slot) {
    final name = switch (slot) {
      _MealSlot.all => 'All',
      _MealSlot.breakfast => 'Breakfast',
      _MealSlot.lunch => 'Lunch',
      _MealSlot.dinner => 'Dinner',
    };
    if (_mealSlot == slot && _dailyItemsCustomerCount != null) {
      return '$name (${_dailyItemsCustomerCount})';
    }
    return name;
  }

  String _dietFilterLabel(_DailyItemsChip chip) {
    return switch (chip) {
      _DailyItemsChip.all => 'All (${_dailyItems.length})',
      _DailyItemsChip.veg => 'Veg ($_vegItemsCount)',
      _DailyItemsChip.nonVeg => 'Non-Veg ($_nonVegItemsCount)',
    };
  }

  static const TextStyle _itemsFilterLabelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle _itemsDropdownTextStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ── Customer-list style dropdown pills (for Daily Items filters) ───────────

  String _mealPillLabel() => 'Meal (${_slotChipLabel(_mealSlot)})';

  String _dietPillLabel() => 'Diet (${_dietFilterLabel(_itemsChip)})';

  Widget _filterPill({
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: onTap == null ? AppColors.textHint : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMealFilterSheet() async {
    if (_itemsListLoading) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget item(_MealSlot v, String label) {
          final sel = _mealSlot == v;
          return InkWell(
            onTap: () async {
              Navigator.pop(ctx);
              await _onMealSlotSelected(v);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: sel ? AppColors.primary : AppColors.textHint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Meal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppColors.border),
                  ..._MealSlot.values.map((v) {
                    final label = _slotChipLabel(v);
                    return Column(
                      children: [
                        item(v, label),
                        if (v != _MealSlot.values.last)
                          Container(height: 1, color: AppColors.border),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDietFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget item(_DailyItemsChip v, String label) {
          final sel = _itemsChip == v;
          return InkWell(
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _itemsChip = v);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: sel ? AppColors.primary : AppColors.textHint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Diet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppColors.border),
                  ..._DailyItemsChip.values.map((v) {
                    final label = _dietFilterLabel(v);
                    return Column(
                      children: [
                        item(v, label),
                        if (v != _DailyItemsChip.values.last)
                          Container(height: 1, color: AppColors.border),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _emptyDailyItemsMessage() {
    final isToday = _isItemsDayToday();
    final slot = _mealSlot;
    if (slot == _MealSlot.all) {
      return isToday ? 'No items for today' : 'No items for this date';
    }
    final label = switch (slot) {
      _MealSlot.breakfast => 'Breakfast',
      _MealSlot.lunch => 'Lunch',
      _MealSlot.dinner => 'Dinner',
      _MealSlot.all => '',
    };
    return isToday
        ? 'No items for $label today'
        : 'No items for $label on this date';
  }

  bool _isItemsDayToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(_itemsDay.year, _itemsDay.month, _itemsDay.day);
    return d == today;
  }

  Future<void> _pickItemsDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _itemsDay,
      firstDate: DateTime.now().subtract(const Duration(days: 500)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    // Normalize web date-picker result so intl / DateTime fields are always valid Dart dates.
    final normalized = DateTime.fromMillisecondsSinceEpoch(
      picked.millisecondsSinceEpoch,
      isUtc: picked.isUtc,
    );
    setState(() {
      _itemsDay = DateTime(normalized.year, normalized.month, normalized.day);
    });
    await _loadDailyItems();
  }

  String _itemsPrepareSubtitle() {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d = DateTime(_itemsDay.year, _itemsDay.month, _itemsDay.day);
      if (d == today) return 'Today';
      return DateFormat('EEE, d MMM yyyy', 'en').format(d);
    } catch (_) {
      return 'Today';
    }
  }

  int get _vegItemsCount =>
      _dailyItems.where((e) => matchesVegItemName(e.name)).length;

  int get _nonVegItemsCount => _dailyItems.length - _vegItemsCount;

  List<DailyItemRow> get _filteredDailyItems {
    switch (_itemsChip) {
      case _DailyItemsChip.all:
        return _dailyItems;
      case _DailyItemsChip.veg:
        return _dailyItems.where((e) => matchesVegItemName(e.name)).toList();
      case _DailyItemsChip.nonVeg:
        return _dailyItems.where((e) => !matchesVegItemName(e.name)).toList();
    }
  }

  Widget _dailyItemsListShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      period: const Duration(milliseconds: 1200),
      child: Column(
        children: List.generate(
          6,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 72,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    int customersCount = 0;
    int ordersCount = 0;
    int deliveryCount = 0;

    try {
      final res = await CustomerApi.list(page: 1, limit: 1);
      final total = res['total'];
      if (total is num) {
        customersCount = total.toInt();
      } else {
        customersCount = res['data'] is List ? (res['data'] as List).length : 0;
      }
    } catch (_) {}
    if (mounted) setState(() => _customersCount = customersCount);

    var ordPending = 0;
    var ordProcessing = 0;
    var ordOut = 0;
    var ordDelivered = 0;
    var ordCancelled = 0;
    try {
      final orders = await OrderApi.getToday(
        mealPeriod: _mealSlotQueryParam(_mealSlot),
      );
      ordersCount = orders.length;
      for (final order in orders) {
        switch (OrderStatus.fromApi(order.status)) {
          case OrderStatus.pending:
            ordPending++;
            break;
          case OrderStatus.processing:
            ordProcessing++;
            break;
          case OrderStatus.outForDelivery:
            ordOut++;
            break;
          case OrderStatus.delivered:
            ordDelivered++;
            break;
          case OrderStatus.cancelled:
            ordCancelled++;
            break;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _ordersCount = ordersCount;
        _ordersPendingCount = ordPending;
        _ordersProcessingCount = ordProcessing;
        _ordersOutForDeliveryCount = ordOut;
        _ordersDeliveredCount = ordDelivered;
        _ordersCancelledCount = ordCancelled;
      });
    }

    try {
      final response = await DioClient.instance.get(
        ApiEndpoints.deliveryStaff,
        queryParameters: {'page': 1, 'limit': 1},
      );
      final data = parseData(response);
      if (data is Map<String, dynamic> && data['total'] is num) {
        deliveryCount = (data['total'] as num).toInt();
      } else {
        final staff = await DeliveryApi.listStaff(page: 1, limit: 500);
        deliveryCount = staff.length;
      }
    } catch (_) {
      try {
        final staff = await DeliveryApi.listStaff(page: 1, limit: 500);
        deliveryCount = staff.length;
      } catch (_) {}
    }
    if (mounted) setState(() => _deliveryStaffCount = deliveryCount);

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait<void>([
          _loadStats(),
          _loadDailyItems(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Greeting + Date pill ─────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()},',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.adminName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _todayDate(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Date pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Text('TODAY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1)),
                      Text(DateTime.now().day.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary, height: 1.1)),
                      Text(
                        const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][DateTime.now().month - 1],
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Today's orders (horizontal strip, above items count) ─
            Row(
              children: [
                const Expanded(
                  child: _SectionLabel(label: "Today's orders"),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.delivery),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryAccent,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Open delivery',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: SizedBox(
                        height: _kTodayOrdersStripHeight,
                        child: Shimmer.fromColors(
                          baseColor: AppColors.shimmerBase,
                          highlightColor: AppColors.shimmerHighlight,
                          child: Row(
                            children: List.generate(
                              6,
                              (i) => Padding(
                                padding: EdgeInsets.only(right: i < 5 ? 10 : 0),
                                child: Container(
                                  width: _kTodayOrdersTileWidth,
                                  height: _kTodayOrdersStripHeight,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            scrollbarTheme: ScrollbarThemeData(
                              thumbVisibility:
                                  const WidgetStatePropertyAll<bool>(true),
                              thickness:
                                  const WidgetStatePropertyAll<double>(3),
                              radius: const Radius.circular(4),
                              crossAxisMargin: 0,
                              mainAxisMargin: 4,
                              thumbColor: WidgetStateProperty.resolveWith(
                                (states) {
                                  if (states.contains(WidgetState.dragged)) {
                                    return AppColors.primary;
                                  }
                                  return AppColors.primary
                                      .withValues(alpha: 0.45);
                                },
                              ),
                              trackColor: const WidgetStatePropertyAll<
                                  Color>(Colors.transparent),
                              trackBorderColor: const WidgetStatePropertyAll<
                                  Color>(Colors.transparent),
                            ),
                          ),
                          child: Scrollbar(
                            controller: _todayOrdersStripController,
                            thumbVisibility: true,
                            trackVisibility: false,
                            thickness: 3,
                            radius: const Radius.circular(4),
                            interactive: true,
                            child: SingleChildScrollView(
                              controller: _todayOrdersStripController,
                              scrollDirection: Axis.horizontal,
                              primary: false,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                10,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth - 24,
                                ),
                                child: Row(
                                  children: [
                                    _OrderStatusCountTile(
                                      width: _kTodayOrdersTileWidth,
                                      label: 'Total',
                                      count: _ordersCount,
                                      icon: Icons.receipt_long_rounded,
                                      accent: const Color(0xFF1D9E75),
                                    ),
                                    const SizedBox(width: 10),
                                    _OrderStatusCountTile(
                                      width: _kTodayOrdersTileWidth,
                                      label: 'Pending',
                                      count: _ordersPendingCount,
                                      icon: Icons.schedule_rounded,
                                      accent: AppColors.warning,
                                    ),
                                    const SizedBox(width: 10),
                                    _OrderStatusCountTile(
                                      width: _kTodayOrdersTileWidth,
                                      label: 'Processing',
                                      count: _ordersProcessingCount,
                                      icon: Icons.restaurant_rounded,
                                      accent: AppColors.processingChipText,
                                    ),
                                    const SizedBox(width: 10),
                                    _OrderStatusCountTile(
                                      width: _kTodayOrdersTileWidth,
                                      label: 'Out for delivery',
                                      count: _ordersOutForDeliveryCount,
                                      icon: Icons.delivery_dining_rounded,
                                      accent: AppColors.primaryAccent,
                                    ),
                                    const SizedBox(width: 10),
                                    _OrderStatusCountTile(
                                      width: _kTodayOrdersTileWidth,
                                      label: 'Delivered',
                                      count: _ordersDeliveredCount,
                                      icon: Icons.check_circle_outline_rounded,
                                      accent: const Color(0xFF0F6E56),
                                    ),
                                    const SizedBox(width: 10),
                                    _OrderStatusCountTile(
                                      width: _kTodayOrdersTileWidth,
                                      label: 'Cancelled',
                                      count: _ordersCancelledCount,
                                      icon: Icons.cancel_outlined,
                                      accent: AppColors.error,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 2),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Items to Prepare ───────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _itemsPrepareTitle(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _itemsListLoading
                                    ? _itemsPrepareSubtitle()
                                    : '${_itemsPrepareSubtitle()} · ${_filteredDailyItems.length} items',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _itemsListLoading ? null : _loadDailyItems,
                          icon: _itemsListLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          color: AppColors.primary,
                        ),
                        IconButton(
                          tooltip: 'Pick date',
                          onPressed: _itemsListLoading ? null : _pickItemsDate,
                          icon: const Icon(Icons.calendar_month_rounded),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Meal', style: _itemsFilterLabelStyle),
                              const SizedBox(height: 6),
                              _filterPill(
                                label: _mealPillLabel(),
                                onTap: _itemsListLoading ? null : _openMealFilterSheet,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Diet', style: _itemsFilterLabelStyle),
                              const SizedBox(height: 6),
                              _filterPill(
                                label: _dietPillLabel(),
                                onTap: _openDietFilterSheet,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_itemsListLoading)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      child: _dailyItemsListShimmer(),
                    )
                  else if (_itemsError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Column(
                        children: [
                          Text(
                            'Could not load items.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _loadDailyItems,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_filteredDailyItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Center(
                        child: Text(
                          _emptyDailyItemsMessage(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredDailyItems.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                      itemBuilder: (context, index) {
                        final row = _filteredDailyItems[index];
                        final qtyLabel =
                            'x ${row.totalQuantity} ${row.unit}'.trim();
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row.name.isNotEmpty ? row.name : '—',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                qtyLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Overview 3 stat cards ─────────────────────────
            const _SectionLabel(label: 'Overview'),
            const SizedBox(height: 10),

            if (_loading)
              Row(
                children: List.generate(3, (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                    child: const _ShimmerCard(),
                  ),
                )),
              )
            else
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Customers', value: _customersCount.toString(), icon: Icons.people_outline_rounded, iconBg: AppColors.primary.withValues(alpha: 0.08), iconColor: AppColors.primary, valueColor: AppColors.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(label: 'Orders', value: _ordersCount.toString(), icon: Icons.receipt_long_outlined, iconBg: const Color(0xFF1D9E75).withValues(alpha: 0.08), iconColor: const Color(0xFF1D9E75), valueColor: const Color(0xFF1D9E75))),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(label: 'Delivery', value: _deliveryStaffCount.toString(), icon: Icons.delivery_dining_outlined, iconBg: const Color(0xFFBA7517).withValues(alpha: 0.08), iconColor: const Color(0xFFBA7517), valueColor: const Color(0xFFBA7517))),
                ],
              ),

            const SizedBox(height: 20),

            // ── Quick Actions ─────────────────────────────────
            const _SectionLabel(label: 'Quick Actions'),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: _QuickActionTile(icon: Icons.person_add_outlined, label: 'Add Customer', subtitle: 'Register new', iconBg: AppColors.primary.withValues(alpha: 0.08), iconColor: AppColors.primary, onTap: () => context.push(AppRoutes.addCustomer))),
                const SizedBox(width: 10),
                Expanded(child: _QuickActionTile(icon: Icons.assignment_outlined, label: 'Assign Plan', subtitle: 'Set meal plan', iconBg: const Color(0xFF1D9E75).withValues(alpha: 0.08), iconColor: const Color(0xFF1D9E75), onTap: () => context.push(AppRoutes.planAssignments))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.delivery_dining_outlined,
                    label: 'Delivery',
                    subtitle: 'Track orders',
                    iconBg: const Color(0xFFBA7517).withValues(alpha: 0.08),
                    iconColor: const Color(0xFFBA7517),
                    onTap: () => context.push(AppRoutes.delivery),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()),
              ],
            ),

          ],
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8));
  }
}

/// Compact count pill for the horizontal “today’s orders” strip (neutral card).
class _OrderStatusCountTile extends StatelessWidget {
  const _OrderStatusCountTile({
    required this.width,
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
  });

  final double width;
  final String label;
  final int count;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: _kTodayOrdersStripHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.iconBg, required this.iconColor, required this.valueColor});
  final String label, value;
  final IconData icon;
  final Color iconBg, iconColor, valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: iconColor)),
        const SizedBox(height: 10),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: valueColor, height: 1))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ── Shimmer Card ──────────────────────────────────────────────────────────────
class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 10),
        Container(width: 40, height: 22, decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 6),
        Container(width: 60, height: 12, decoration: BoxDecoration(color: AppColors.shimmerHighlight, borderRadius: BorderRadius.circular(4))),
      ]),
    );
  }
}

// ── Quick Action Tile ─────────────────────────────────────────────────────────
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.icon, required this.label, required this.subtitle, required this.iconBg, required this.iconColor, required this.onTap});
  final IconData icon;
  final String label, subtitle;
  final Color iconBg, iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 22, color: iconColor)),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}