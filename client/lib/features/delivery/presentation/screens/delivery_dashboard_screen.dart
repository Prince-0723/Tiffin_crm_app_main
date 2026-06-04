import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/delivery/staff_location_sync.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/location_helper.dart';
import '../../../../core/routing/nominatim_geocode_service.dart';
import '../../../../core/utils/whatsapp_helper.dart';
import '../../../../core/widgets/notification_bell_icon.dart';
import '../../data/delivery_api.dart';
import '../../../auth/data/auth_api.dart';
import '../../../orders/data/order_api.dart';
import '../../../orders/models/order_model.dart';
import '../../../orders/models/order_status.dart';
import 'delivery_map_screen.dart';
import '../models/delivery_map_session.dart';
import 'delivery_profile_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() =>
      _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  // ── Amber × Violet mixed palette ──────────────────────────────────────────
  static const _violet900 = Color(0xFF1E0A4A);
  static const _violet800 = Color(0xFF3B0FA0);
  static const _violet700 = Color(0xFF5B21B6);
  static const _violet600 = Color(0xFF7C3AED);
  static const _violet500 = Color(0xFF8B5CF6);
  static const _violet200 = Color(0xFFDDD6FE);
  static const _violet100 = Color(0xFFEDE9FE);
  static const _violet50 = Color(0xFFF5F3FF);

  static const _amber700 = Color(0xFFB45309);
  static const _amber600 = Color(0xFFD97706);
  static const _amber400 = Color(0xFFFBBF24);
  static const _amber100 = Color(0xFFFEF3C7);
  static const _amber50 = Color(0xFFFFFBEB);

  // Gradient hero: deep violet → amber glow
  static const _gradStart = Color(0xFFD97706);
  static const _gradMid = Color(0xFFF59E0B);
  static const _gradEnd = Color(0xFFFBBF24);

  static const _bg = Color(0xFFFAF8FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFEDE9FE);
  static const _divider = Color(0xFFF0EBFF);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7C6DAB);

  static const _success = Color(0xFF059669);
  static const _successSoft = Color(0xFFD1FAE5);
  static const _danger = Color(0xFFDC2626);
  static const _dangerSoft = Color(0xFFFEE2E2);

  // ── State ─────────────────────────────────────────────────────────────────
  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _statusFilter;
  bool _updatingLocation = false;
  int _selectedTab = 0;
  Timer? _locationTimer;
  DeliveryMapSession? _mapSession;

  static const List<String?> _filterValues = [
    null,
    'pending',
    'processing',
    'out_for_delivery',
    'delivered',
  ];
  static const List<String> _filterLabels = [
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
    DeliveryTrackingSocket.instance.ensureConnected();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _updateLocationSilent();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateLocationSilent() async {
    try {
      final position = await LocationHelper.getCurrentPosition();
      if (position == null || !mounted) return;
      await StaffLocationSync.pushFromPosition(position, _orders);
    } catch (_) {}
  }

  Future<void> _openCustomerRouteOnMap(
    BuildContext sheetContext,
    OrderModel order,
  ) async {
    final address = order.customerAddress?.trim();
    if (address == null || address.isEmpty) {
      if (sheetContext.mounted) {
        AppSnackbar.error(sheetContext, 'Could not find customer location');
      }
      return;
    }
    try {
      final pt = await NominatimGeocodeService.searchFirst(address);
      if (!sheetContext.mounted) return;
      if (pt == null) {
        AppSnackbar.error(sheetContext, 'Could not find customer location');
        return;
      }
      Navigator.pop(sheetContext);
      setState(() {
        _mapSession = DeliveryMapSession.singleRoute(
          customerPoint: pt,
          customerName: order.customerName ?? order.customerId,
        );
        _selectedTab = 1;
      });
    } catch (_) {
      if (sheetContext.mounted) {
        AppSnackbar.error(sheetContext, 'Could not find customer location');
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await DeliveryApi.getMyDeliveries();
      if (mounted) setState(() => _orders = list);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<OrderModel> get _filteredOrders {
    if (_statusFilter == null) return _orders;
    return _orders.where((o) => o.status == _statusFilter).toList();
  }

  Future<void> _shareMyLocation() async {
    setState(() => _updatingLocation = true);
    try {
      final position = await LocationHelper.getCurrentPosition();
      if (position == null || !mounted) return;
      await StaffLocationSync.pushFromPosition(position, _orders);
      if (mounted) AppSnackbar.success(context, 'Location shared');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  Future<void> _logout() async {
    final router = GoRouter.of(context);
    await AuthApi.logout();
    await AuthSession.clearLocalSession();
    if (!mounted) return;
    router.go(AppRoutes.roleSelection);
  }

  void _showOrderSheet(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OrderActionSheet(
        order: order,
        onAccept: () async {
          try {
            await OrderApi.accept(order.id);
            await OrderApi.updateStatus(order.id, 'out_for_delivery');
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            if (ctx.mounted) ErrorHandler.show(ctx, e);
          }
        },
        onReject: () async {
          final reason = await showDialog<String>(
            context: ctx,
            builder: (c) {
              final controller = TextEditingController();
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text(
                  'Reject delivery',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                content: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'e.g. Too far, unavailable',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  maxLines: 2,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, controller.text.trim()),
                    style: FilledButton.styleFrom(backgroundColor: _danger),
                    child: const Text('Reject'),
                  ),
                ],
              );
            },
          );
          if (reason == null) return;
          try {
            await OrderApi.reject(
              order.id,
              reason: reason.isEmpty ? 'Rejected' : reason,
            );
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            if (ctx.mounted) ErrorHandler.show(ctx, e);
          }
        },
        onStartDelivery: () async {
          try {
            await OrderApi.updateStatus(order.id, 'out_for_delivery');
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            if (ctx.mounted) ErrorHandler.show(ctx, e);
          }
        },
        onMarkDelivered: () async {
          try {
            await OrderApi.updateStatus(order.id, 'delivered');
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            if (ctx.mounted) ErrorHandler.show(ctx, e);
          }
        },
        onWhatsApp: () {
          final phone = order.customerPhone;
          if (phone != null && phone.isNotEmpty) WhatsAppHelper.openChat(phone);
        },
        onCall: () {
          final phone = order.customerPhone;
          if (phone != null && phone.isNotEmpty) {
            WhatsAppHelper.callPhone(phone);
          }
        },
        onOpenMaps: () => _openCustomerRouteOnMap(ctx, order),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final tabTitles = ['My Tasks', 'Map View', 'Profile'];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_gradStart, _gradMid, _gradEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          tabTitles[_selectedTab],
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          NotificationBellIcon(
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          if (_selectedTab == 0) ...[
            IconButton(
              icon: _updatingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const PhosphorIcon(
                      PhosphorIconsRegular.mapPin,
                      size: 20,
                      color: Colors.white,
                    ),
              tooltip: 'Share my location',
              onPressed: _updatingLocation ? null : _shareMyLocation,
            ),
            IconButton(
              icon: const PhosphorIcon(
                PhosphorIconsRegular.arrowsClockwise,
                size: 20,
                color: Colors.white,
              ),
              onPressed: _loading ? null : _load,
            ),
            PopupMenuButton<void>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: _logout,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _dangerSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: _danger,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        bottom: _selectedTab == 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_gradStart, _gradMid],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Row(
                      children: List.generate(_filterLabels.length, (i) {
                        final selected = _statusFilter == _filterValues[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _statusFilter = _filterValues[i],
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _amber400
                                    : Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? _amber600
                                      : Colors.white.withOpacity(0.3),
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                _filterLabels[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? _violet900 : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          RepaintBoundary(child: _buildTasksBody(filtered)),
          RepaintBoundary(
            child: DeliveryMapScreen(
              showAppBar: false,
              orders: _orders,
              session: _mapSession,
            ),
          ),
          const RepaintBoundary(
            child: DeliveryProfileScreen(),
          ),
        ],
      ),

      // ── Bottom nav ─────────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: _violet900.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavTab(
                  icon: PhosphorIconsRegular.clipboardText,
                  iconFill: PhosphorIconsFill.clipboardText,
                  label: 'Tasks',
                  selected: _selectedTab == 0,
                  badge: _orders
                      .where(
                        (o) => o.status == 'pending' || o.status == 'assigned',
                      )
                      .length,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedTab = 0;
                      _mapSession = null;
                    });
                  },
                ),
                _NavTab(
                  icon: PhosphorIconsRegular.mapTrifold,
                  iconFill: PhosphorIconsFill.mapTrifold,
                  label: 'Map',
                  selected: _selectedTab == 1,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedTab = 1);
                  },
                ),
                _NavTab(
                  icon: PhosphorIconsRegular.user,
                  iconFill: PhosphorIconsFill.user,
                  label: 'Profile',
                  selected: _selectedTab == 2,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedTab = 2);
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              heroTag: 'delivery_staff_fab_view_map',
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _mapSession = const DeliveryMapSession.multiOnWay();
                  _selectedTab = 1;
                });
              },
              backgroundColor: _violet600,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const PhosphorIcon(
                PhosphorIconsRegular.mapTrifold,
                size: 18,
              ),
              label: const Text(
                'View on Map',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            )
          : null,
    );
  }

  // ── Tasks body ────────────────────────────────────────────────────────────
  Widget _buildTasksBody(List<OrderModel> filtered) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _violet600, strokeWidth: 2.5),
            const SizedBox(height: 12),
            Text(
              'Loading deliveries…',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _violet600,
      onRefresh: _load,
      child: filtered.isEmpty
          ? ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_violet100, _amber100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _violet200),
                        ),
                        child: const Icon(
                          Icons.inbox_outlined,
                          size: 36,
                          color: _violet600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No deliveries assigned',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(fontSize: 13, color: _textSecondary),
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
                16,
                16,
                MediaQuery.of(context).padding.bottom + 100,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) => RepaintBoundary(
                    child: _buildOrderCard(filtered[index]),
                  ),
            ),
    );
  }

  // ── Order card ────────────────────────────────────────────────────────────
  Widget _buildOrderCard(OrderModel order) {
    final name = order.customerName ?? order.customerId;
    final initials = _getInitials(name);
    final statusMeta = _statusMeta(order.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showOrderSheet(order);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _violet900.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left accent bar — gradient violet→amber
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusMeta.$1, _amber400],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        // Avatar — violet/amber gradient bg
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_violet100, _amber100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: _violet200),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _violet700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (order.customerAddress != null &&
                                  order.customerAddress!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  order.customerAddress!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _amber50,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: _amber400.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 10,
                                          color: _amber700,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          order.slot ?? '—',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: _amber700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusMeta.$2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusMeta.$1.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            statusMeta.$3,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: statusMeta.$1,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Chevron
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  (Color, Color, String) _statusMeta(String status) {
    final o = OrderStatus.fromApi(status);
    switch (o) {
      case OrderStatus.pending:
        return (_amber600, _amber100, o.label);
      case OrderStatus.processing:
        return (_amber700, _amber50, o.label);
      case OrderStatus.outForDelivery:
        return (_violet600, _violet100, o.label);
      case OrderStatus.delivered:
        return (_success, _successSoft, o.label);
      case OrderStatus.cancelled:
        return (_danger, _dangerSoft, o.label);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom bottom nav tab
// ─────────────────────────────────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.iconFill,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData iconFill;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  static const _violet600 = Color(0xFF7C3AED);
  static const _violet100 = Color(0xFFEDE9FE);
  static const _amber400 = Color(0xFFFBBF24);
  static const _textSecondary = Color(0xFF7C6DAB);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: selected ? _violet100 : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  // Amber bottom glow when selected
                  border: selected
                      ? Border(bottom: BorderSide(color: _amber400, width: 2))
                      : null,
                ),
                child: PhosphorIcon(
                  selected ? iconFill : icon,
                  size: 22,
                  color: selected ? _violet600 : _textSecondary,
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFDC2626)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? _violet600 : _textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Order action bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _OrderActionSheet extends StatelessWidget {
  const _OrderActionSheet({
    required this.order,
    required this.onAccept,
    required this.onReject,
    required this.onStartDelivery,
    required this.onMarkDelivered,
    required this.onWhatsApp,
    required this.onCall,
    required this.onOpenMaps,
  });

  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onStartDelivery;
  final VoidCallback onMarkDelivered;
  final VoidCallback onWhatsApp;
  final VoidCallback onCall;
  final VoidCallback onOpenMaps;

  static const _violet900 = Color(0xFF1E0A4A);
  static const _violet700 = Color(0xFF5B21B6);
  static const _violet600 = Color(0xFF7C3AED);
  static const _violet100 = Color(0xFFEDE9FE);
  static const _violet50 = Color(0xFFF5F3FF);
  static const _amber700 = Color(0xFFB45309);
  static const _amber600 = Color(0xFFD97706);
  static const _amber400 = Color(0xFFFBBF24);
  static const _amber100 = Color(0xFFFEF3C7);
  static const _amber50 = Color(0xFFFFFBEB);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFEDE9FE);
  static const _divider = Color(0xFFF0EBFF);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7C6DAB);
  static const _success = Color(0xFF059669);
  static const _successSoft = Color(0xFFD1FAE5);
  static const _danger = Color(0xFFDC2626);
  static const _dangerSoft = Color(0xFFFEE2E2);

  @override
  Widget build(BuildContext context) {
    final status = order.status.toLowerCase();
    final needsAcceptReject =
        status == 'pending' || status == 'to_process' || status == 'assigned';
    final canStart =
        status != 'in_transit' &&
        status != 'delivered' &&
        status != 'out_for_delivery';
    final canDeliver = status == 'in_transit' || status == 'out_for_delivery';

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar — amber tinted
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_violet600, _amber600]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Customer info — violet/amber gradient header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5F3FF), Color(0xFFFFFBEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_violet700, _amber600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(order.customerName ?? order.customerId),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
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
                        order.customerName ?? order.customerId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      if (order.customerAddress != null)
                        Text(
                          order.customerAddress!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_violet100, _amber100],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _violet600.withOpacity(0.2)),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _violet700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Slot chip
          if (order.slot != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _amber50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber400.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: _amber700,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Slot: ${order.slot}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _amber700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: _divider, height: 1),
          const SizedBox(height: 16),

          // Accept / Reject
          if (needsAcceptReject) ...[
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    label: 'Accept',
                    icon: Icons.check_circle_outline_rounded,
                    bg: _successSoft,
                    fg: _success,
                    border: _success,
                    onTap: onAccept,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetButton(
                    label: 'Reject',
                    icon: Icons.cancel_outlined,
                    bg: _dangerSoft,
                    fg: _danger,
                    border: _danger,
                    onTap: onReject,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Start delivery
          if (canStart && !needsAcceptReject) ...[
            _SheetButton(
              label: 'Start Delivery',
              icon: Icons.delivery_dining_rounded,
              bg: _violet100,
              fg: _violet700,
              border: _violet600,
              onTap: onStartDelivery,
              filled: true,
            ),
            const SizedBox(height: 10),
          ],

          // Mark delivered
          if (canDeliver) ...[
            _SheetButton(
              label: 'Mark Delivered',
              icon: Icons.task_alt_rounded,
              bg: _successSoft,
              fg: _success,
              border: _success,
              onTap: onMarkDelivered,
              filled: true,
            ),
            const SizedBox(height: 10),
          ],

          // Contact row
          Row(
            children: [
              Expanded(
                child: _SheetButton(
                  label: 'WhatsApp',
                  icon: Icons.chat_outlined,
                  bg: const Color(0xFFD1FAE5),
                  fg: const Color(0xFF065F46),
                  border: const Color(0xFF059669),
                  onTap: onWhatsApp,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SheetButton(
                  label: 'Call',
                  icon: Icons.phone_outlined,
                  bg: _violet50,
                  fg: _violet600,
                  border: _violet600,
                  onTap: onCall,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SheetButton(
                  label: 'Maps',
                  icon: Icons.map_outlined,
                  bg: _amber50,
                  fg: _amber700,
                  border: _amber600,
                  onTap: onOpenMaps,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _textSecondary),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet action button
// ─────────────────────────────────────────────────────────────────────────────

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.border,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final Color bg, fg, border;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withOpacity(0.4)),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: fg.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}
