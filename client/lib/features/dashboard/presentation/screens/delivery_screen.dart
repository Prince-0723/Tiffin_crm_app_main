import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/whatsapp_helper.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../../delivery/data/delivery_api.dart';
import '../../../delivery/models/delivery_staff_model.dart';
import '../../../orders/data/order_api.dart';
import '../../../orders/models/order_model.dart';

// ─── Purple Accent Pro palette ───────────────────────────────────────────────
class _P {
  static const g1 = Color(0xFF7B3FE4);
  static const v700 = Color(0xFF5B21B6);
  static const v600 = Color(0xFF7C3AED);
  static const v500 = Color(0xFF8B5CF6);
  static const v400 = Color(0xFFA78BFA);
  static const v200 = Color(0xFFDDD6FE);
  static const v100 = Color(0xFFEDE9FE);
  static const v50 = Color(0xFFF5F3FF);
  static const bg = Color(0xFFF0EBFF);
  static const s900 = Color(0xFF0F172A);
  static const s700 = Color(0xFF334155);
  static const s600 = Color(0xFF475569);
  static const s500 = Color(0xFF64748B);
  static const s400 = Color(0xFF94A3B8);
  static const s300 = Color(0xFFCBD5E1);
  static const s200 = Color(0xFFE2E8F0);
  static const s100 = Color(0xFFF8FAFC);
  static const greenBg = Color(0xFFF0FDF4);
  static const greenTxt = Color(0xFF166534);
  static const greenBdr = Color(0xFF86EFAC);
  static const amberBg = Color(0xFFFFFBEB);
  static const amberTxt = Color(0xFF92400E);
  static const amberBdr = Color(0xFFFCD34D);
  static const blueBg = Color(0xFFEFF6FF);
  static const blueTxt = Color(0xFF1D4ED8);
  static const blueBdr = Color(0xFFBFDBFE);
  static const redBg = Color(0xFFFEF2F2);
  static const redTxt = Color(0xFF991B1B);
  static const redBdr = Color(0xFFFCA5A5);
  static const grayBg = Color(0xFFF1F5F9);
  static const grayTxt = Color(0xFF475569);
  static const grayBdr = Color(0xFFCBD5E1);
}

// ─── Status style helper ─────────────────────────────────────────────────────
class _StatusStyle {
  final Color bg, txt, bdr, accent, dot;
  final String label;
  const _StatusStyle({
    required this.bg,
    required this.txt,
    required this.bdr,
    required this.accent,
    required this.dot,
    required this.label,
  });
}

enum _MealTimeFilter { all, breakfast, lunch, dinner }

enum _OrderSort { apiDefault, nameAz, nameZa }

_StatusStyle _ss(String status) {
  switch (status.toLowerCase()) {
    case 'out_for_delivery':
      return const _StatusStyle(
        bg: _P.blueBg,
        txt: _P.blueTxt,
        bdr: _P.blueBdr,
        accent: Color(0xFF2563EB),
        dot: Color(0xFF2563EB),
        label: 'Out for delivery',
      );
    case 'delivered':
      return const _StatusStyle(
        bg: _P.greenBg,
        txt: _P.greenTxt,
        bdr: _P.greenBdr,
        accent: Color(0xFF22C55E),
        dot: Color(0xFF16A34A),
        label: 'Delivered',
      );
    case 'processing':
      return const _StatusStyle(
        bg: _P.amberBg,
        txt: _P.amberTxt,
        bdr: _P.amberBdr,
        accent: Color(0xFFF59E0B),
        dot: Color(0xFFD97706),
        label: 'Processing',
      );
    default: // pending
      return const _StatusStyle(
        bg: _P.grayBg,
        txt: _P.grayTxt,
        bdr: _P.grayBdr,
        accent: _P.s400,
        dot: _P.s300,
        label: 'Pending',
      );
  }
}

// ─── Shared badge widget ─────────────────────────────────────────────────────
Widget _badge(_StatusStyle st) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: st.bg,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: st.bdr, width: 0.5),
  ),
  child: Text(
    st.label,
    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: st.txt),
  ),
);

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key, this.embeddedInShell = false});
  final bool embeddedInShell;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  // ── ALL LOGIC UNCHANGED ──
  List<OrderModel> _orders = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _statusFilter;
  _MealTimeFilter _mealTimeFilter = _MealTimeFilter.all;
  _OrderSort? _sort = _OrderSort.apiDefault;
  final Set<String> _selectedIds = {};
  bool _bulkMode = false;
  bool _bulkStatusLoading = false;
  StreamSubscription<void>? _dailyOrdersSocketSub;

  static const List<String> _filterLabels = [
    'All',
    'Pending',
    'Processing',
    'Out for delivery',
    'Delivered',
  ];
  static const List<String?> _filterValues = [
    null,
    'pending',
    'processing',
    'out_for_delivery',
    'delivered',
  ];

  static const List<String> _mealTimeLabels = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
  ];

  static const List<_MealTimeFilter> _mealTimeValues = [
    _MealTimeFilter.all,
    _MealTimeFilter.breakfast,
    _MealTimeFilter.lunch,
    _MealTimeFilter.dinner,
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _attachDailyOrdersSocket();
  }

  /// Refetch when server notifies that today’s daily orders changed (e.g. cancellation).
  Future<void> _attachDailyOrdersSocket() async {
    await DeliveryTrackingSocket.instance.ensureConnected();
    _dailyOrdersSocketSub =
        DeliveryTrackingSocket.instance.dailyOrdersRefresh.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _dailyOrdersSocketSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await DeliveryApi.getAllDeliveries();
      final visible = list
          .where((o) => o.status.toLowerCase() != 'cancelled')
          .toList();
      if (mounted) setState(() => _orders = visible);
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

  static String? _normalizeMealTime(String? raw) {
    final s = raw?.toString().trim().toLowerCase();
    if (s == null || s.isEmpty) return null;
    if (s.startsWith('break')) return 'breakfast';
    if (s.startsWith('lunch')) return 'lunch';
    if (s.startsWith('dinner')) return 'dinner';
    return s;
  }

  List<OrderModel> get _timeFilteredOrders {
    final base = _filteredOrders;
    if (_mealTimeFilter == _MealTimeFilter.all) return base;
    final wanted = switch (_mealTimeFilter) {
      _MealTimeFilter.breakfast => 'breakfast',
      _MealTimeFilter.lunch => 'lunch',
      _MealTimeFilter.dinner => 'dinner',
      _MealTimeFilter.all => null,
    };
    return base.where((o) => _normalizeMealTime(o.mealTime) == wanted).toList();
  }

  List<OrderModel> get _searchedOrders {
    final q = _query.trim().toLowerCase();
    final base = _timeFilteredOrders;
    if (q.isEmpty) return base;
    return base.where((o) {
      final name = (o.customerName ?? '').toLowerCase();
      final phone = (o.customerPhone ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  static String _todayDateStr() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  Future<void> _generate() async {
    try {
      final dateStr = _todayDateStr();
      try {
        await OrderApi.generate(date: dateStr);
      } catch (_) {
        try {
          await OrderApi.process(date: dateStr);
        } catch (_) {}
      }
      if (mounted) {
        AppSnackbar.success(context, 'Orders generated for today');
        await _load();
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<void> _process() async {
    try {
      final dateStr = _todayDateStr();
      await OrderApi.process(date: dateStr);
      if (mounted) {
        AppSnackbar.success(context, 'Orders processed');
        await _load();
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<void> _confirmBulkStatusUpdate(
    String apiStatus,
    String actionDescription,
  ) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) {
      AppSnackbar.error(
        context,
        'Select orders first: tap Bulk, then tap each order to select.',
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.layers_outlined, color: _P.v600, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Bulk status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _P.s900,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$actionDescription for ${ids.length} selected order(s)?',
          style: const TextStyle(
            fontSize: 13,
            color: _P.s600,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _P.s600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _P.v600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _bulkStatusLoading = true);
    try {
      final result = await OrderApi.updateStatusBulk(ids, apiStatus);
      if (!mounted) return;

      final parts = <String>[];
      if (result.updatedCount > 0) {
        parts.add('Updated ${result.updatedCount}');
      }
      if (result.skippedSameStatus > 0) {
        parts.add('${result.skippedSameStatus} already had this status');
      }
      if (result.skippedInvalidTransition > 0) {
        parts.add(
          '${result.skippedInvalidTransition} skipped (cannot move from current status)',
        );
      }
      if (result.notFoundCount > 0) {
        parts.add('${result.notFoundCount} not found');
      }
      if (result.failures.isNotEmpty) {
        final msg = result.failures.first.message;
        parts.add(
          result.failures.length == 1
              ? 'Failed: $msg'
              : '${result.failures.length} failed (${msg}…)',
        );
      }

      final summary = parts.join('. ');
      AppSnackbar.success(
        context,
        summary.isEmpty ? 'No orders changed' : summary,
      );
      await _load();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _bulkStatusLoading = false);
    }
  }

  void _showOrderSheet(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OrderDetailSheet(
        order: order,
        onAssign: () => _openAssignSheet(
          ctx,
          [order.id],
          closeParentSheetOnAssigned: true,
        ),
        onStatusChange: (status) async {
          try {
            await OrderApi.updateStatus(order.id, status);
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            if (ctx.mounted) ErrorHandler.show(ctx, e);
          }
        },
        onWhatsApp: () {
          final phone = order.customerPhone;
          if (phone != null && phone.isNotEmpty) {
            WhatsAppHelper.openChat(phone);
          } else {
            AppSnackbar.error(context, 'No phone number');
          }
        },
      ),
    );
  }

  Future<void> _openAssignSheet(
    BuildContext sheetContext,
    List<String> orderIds,
    {bool closeParentSheetOnAssigned = false}
  ) async {
    List<DeliveryStaffModel> staff = [];
    try {
      staff = await DeliveryApi.listStaff(limit: 50, isActive: true);
    } catch (e) {
      if (sheetContext.mounted) ErrorHandler.show(sheetContext, e);
      return;
    }
    if (!sheetContext.mounted) return;
    showModalBottomSheet(
      context: sheetContext,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignStaffSheet(
        staff: staff,
        orderIds: orderIds,
        onAssigned: () {
          Navigator.pop(ctx);
          if (closeParentSheetOnAssigned && sheetContext.mounted) {
            Navigator.pop(sheetContext);
          }
          if (mounted) {
            setState(() {
              _bulkMode = false;
              _selectedIds.clear();
            });
          }
          _load();
        },
      ),
    );
  }

  void _toggleBulkMode() {
    setState(() {
      _bulkMode = !_bulkMode;
      if (!_bulkMode) _selectedIds.clear();
    });
  }

  void _toggleSelect(OrderModel order) {
    setState(() {
      if (_selectedIds.contains(order.id)) {
        _selectedIds.remove(order.id);
      } else {
        _selectedIds.add(order.id);
      }
    });
  }

  // ── Summary counts ──
  int _count(String? status) => status == null
      ? _orders.length
      : _orders.where((o) => o.status == status).length;

  // ── UI HELPERS ────────────────────────────────────────────────────────────

  // Gradient header (standalone mode)
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _P.g1,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
              const Expanded(
                child: Text(
                  'Daily Deliveries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              ..._headerActions(),
            ],
          ),
        ),
      ),
    );
  }

  // Summary row on header
  Widget _buildSummaryRow() {
    return Container(
      color: _P.g1,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          _summaryTile('${_count(null)}', 'Total'),
          const SizedBox(width: 8),
          _summaryTile('${_count("out_for_delivery")}', 'Out for delivery'),
          const SizedBox(width: 8),
          _summaryTile('${_count("pending")}', 'Pending'),
          const SizedBox(width: 8),
          _summaryTile('${_count("delivered")}', 'Done'),
        ],
      ),
    );
  }

  Widget _summaryTile(String count, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    ),
  );

  // Header icon buttons
  List<Widget> _headerActions() => [
    _hdrBtn(Icons.playlist_add, _loading ? null : _generate, 'Generate'),
    const SizedBox(width: 6),
    _hdrBtn(
      Icons.check_circle_outline_rounded,
      _loading ? null : _process,
      'Process',
    ),
    const SizedBox(width: 6),
    _hdrBtn(
      _bulkMode ? Icons.cancel_outlined : Icons.checklist_rounded,
      _toggleBulkMode,
      _bulkMode ? 'Cancel' : 'Bulk',
    ),
  ];

  Widget _hdrBtn(IconData icon, VoidCallback? onTap, String tooltip) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          color: onTap == null
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.white,
          size: 15,
        ),
      ),
    ),
  );

  // Embedded shell title row actions
  // ignore: unused_element
  List<Widget> _appBarActions(Color fg) => [
    IconButton(
      icon: Icon(Icons.playlist_add, color: fg),
      tooltip: 'Generate orders',
      onPressed: _loading ? null : _generate,
    ),
    IconButton(
      icon: Icon(Icons.check_circle_outline, color: fg),
      tooltip: 'Process orders',
      onPressed: _loading ? null : _process,
    ),
    IconButton(
      icon: Icon(_bulkMode ? Icons.cancel : Icons.checklist, color: fg),
      tooltip: _bulkMode ? 'Cancel selection' : 'Bulk assign',
      onPressed: _toggleBulkMode,
    ),
  ];

  // ── Dropdown pills (same style as customer list) ──────────────────────────

  String _sortLabel() {
    final label = switch (_sort ?? _OrderSort.apiDefault) {
      _OrderSort.apiDefault => 'Default',
      _OrderSort.nameAz => 'Name A–Z',
      _OrderSort.nameZa => 'Name Z–A',
    };
    return 'Sort By ($label)';
  }

  String _statusLabel() {
    final i = _filterValues.indexOf(_statusFilter);
    final label = (i >= 0) ? _filterLabels[i] : _filterLabels.first;
    return 'Status ($label)';
  }

  String _mealLabel() {
    final i = _mealTimeValues.indexOf(_mealTimeFilter);
    final label = (i >= 0) ? _mealTimeLabels[i] : _mealTimeLabels.first;
    return 'Meal ($label)';
  }

  Widget _dropdownPill({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _P.s200, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _P.s900,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: _P.s400,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSortSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget item(_OrderSort v, String label) {
          final sel = (_sort ?? _OrderSort.apiDefault) == v;
          return InkWell(
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _sort = v);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: sel ? _P.g1 : _P.s400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _P.s900,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _P.s200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
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
                            'Sort By',
                            style: TextStyle(
                              color: _P.s900,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: _P.s600,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: _P.s200),
                  item(_OrderSort.apiDefault, 'Default'),
                  Container(height: 1, color: _P.s200),
                  item(_OrderSort.nameAz, 'Name A–Z'),
                  Container(height: 1, color: _P.s200),
                  item(_OrderSort.nameZa, 'Name Z–A'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStatusSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget item(String? v, String label) {
          final sel = _statusFilter == v;
          return InkWell(
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _statusFilter = v);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: sel ? _P.g1 : _P.s400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _P.s900,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _P.s200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
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
                            'Status',
                            style: TextStyle(
                              color: _P.s900,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: _P.s600,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: _P.s200),
                  ...List.generate(_filterLabels.length, (i) {
                    return Column(
                      children: [
                        item(_filterValues[i], _filterLabels[i]),
                        if (i != _filterLabels.length - 1)
                          Container(height: 1, color: _P.s200),
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

  Future<void> _openMealSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget item(_MealTimeFilter v, String label) {
          final sel = _mealTimeFilter == v;
          return InkWell(
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _mealTimeFilter = v);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: sel ? _P.g1 : _P.s400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _P.s900,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _P.s200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
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
                              color: _P.s900,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: _P.s600,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: _P.s200),
                  ...List.generate(_mealTimeLabels.length, (i) {
                    return Column(
                      children: [
                        item(_mealTimeValues[i], _mealTimeLabels[i]),
                        if (i != _mealTimeLabels.length - 1)
                          Container(height: 1, color: _P.s200),
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

  Widget _bulkStatusActionsRow() {
    Widget chip(String label, String apiStatus, String confirmBlurb) {
      final canRun = !_bulkStatusLoading && _selectedIds.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton(
          onPressed: canRun
              ? () => _confirmBulkStatusUpdate(apiStatus, confirmBlurb)
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: _P.v700,
            side: const BorderSide(color: _P.v200, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _selectedIds.isEmpty
                  ? 'Bulk status (select orders)'
                  : 'Bulk status (${_selectedIds.length} selected)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _selectedIds.isEmpty ? _P.s400 : _P.s500,
                letterSpacing: 0.4,
              ),
            ),
            if (_bulkStatusLoading) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: _P.v600,
                  strokeWidth: 2,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(
                'Mark Selected Processing',
                'processing',
                'Mark selected orders as Processing',
              ),
              chip(
                'Mark Selected Out for Delivery',
                'out_for_delivery',
                'Mark selected orders as Out for delivery',
              ),
              chip(
                'Mark Selected Delivered',
                'delivered',
                'Mark selected orders as Delivered',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filtersRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        children: [
          _bulkStatusActionsRow(),
          const SizedBox(height: 10),
          // Search bar (same format as customer list)
          Container(
            decoration: BoxDecoration(
              color: _P.s100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _P.s200, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: _P.s400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13, color: _P.s900),
                    decoration: const InputDecoration(
                      hintText: 'Search name, phone…',
                      hintStyle: TextStyle(fontSize: 13, color: _P.s400),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: _P.s400,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _dropdownPill(label: _sortLabel(), onTap: _openSortSheet),
                const SizedBox(width: 8),
                _dropdownPill(label: _statusLabel(), onTap: _openStatusSheet),
                const SizedBox(width: 8),
                _dropdownPill(label: _mealLabel(), onTap: _openMealSheet),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Main body — timeline list
  Widget _bodyContent(List<OrderModel> filtered) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _P.v600, strokeWidth: 2),
      );
    }

    return RefreshIndicator(
      color: _P.v600,
      onRefresh: _load,
      child: filtered.isEmpty
          ? ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: _P.v100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delivery_dining_outlined,
                          color: _P.v500,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No orders found',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _P.s500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _generate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _P.g1,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                "Generate today's orders",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
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
                0,
                6,
                0,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final order = filtered[index];
                final st = _ss(order.status);
                final selected = _selectedIds.contains(order.id);
                final isLast = index == filtered.length - 1;

                final name = (order.customerName?.trim().isNotEmpty == true)
                    ? order.customerName!.trim()
                    : order.customerId;

                final slot = order.slot?.trim();
                final time = (slot != null && slot.isNotEmpty)
                    ? slot
                    : (_normalizeMealTime(order.mealTime) ?? '').trim();

                final staff = order.deliveryStaffName?.trim();
                final parts = <String>[
                  if (time.isNotEmpty)
                    '${time[0].toUpperCase()}${time.substring(1)}',
                  if (staff != null && staff.isNotEmpty) staff,
                ];
                final subtitle = parts.join('  ·  ');

                return RepaintBoundary(
                  child: Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: () {
                      if (_bulkMode) {
                        _toggleSelect(order);
                      } else {
                        _showOrderSheet(order);
                      }
                    },
                    onLongPress: _bulkMode
                        ? null
                        : () => setState(() {
                            _bulkMode = true;
                            _selectedIds.add(order.id);
                          }),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isLast ? Colors.transparent : _P.s100,
                            width: 1,
                          ),
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    if (_bulkMode)
                                      GestureDetector(
                                        onTap: () => _toggleSelect(order),
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: selected ? _P.g1 : _P.s400,
                                              width: 2,
                                            ),
                                            color: selected
                                                ? _P.g1
                                                : Colors.transparent,
                                          ),
                                          child: selected
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    if (_bulkMode) const SizedBox(width: 12),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _P.v100,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _initials(name),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: _P.v700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (_bulkMode && selected) ...[
                                                const Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 16,
                                                  color: _P.g1,
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: (_bulkMode && selected)
                                                        ? _P.g1
                                                        : _P.s900,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              subtitle,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _P.s600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _badge(st),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                );
              },
            ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────────────
  Widget _fab() {
    if (_bulkMode && _selectedIds.isNotEmpty) {
      return FloatingActionButton.extended(
        heroTag: 'delivery_fab_assign',
        onPressed: () => _openAssignSheet(
          context,
          _selectedIds.toList(),
          closeParentSheetOnAssigned: false,
        ),
        backgroundColor: _P.g1,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.person_add_outlined, size: 18),
        label: Text(
          'Assign (${_selectedIds.length})',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = [..._searchedOrders];
    switch (_sort ?? _OrderSort.apiDefault) {
      case _OrderSort.apiDefault:
        break;
      case _OrderSort.nameAz:
        filtered.sort((a, b) {
          final an = (a.customerName ?? '').trim().toLowerCase();
          final bn = (b.customerName ?? '').trim().toLowerCase();
          return an.compareTo(bn);
        });
        break;
      case _OrderSort.nameZa:
        filtered.sort((a, b) {
          final an = (a.customerName ?? '').trim().toLowerCase();
          final bn = (b.customerName ?? '').trim().toLowerCase();
          return bn.compareTo(an);
        });
        break;
    }

    // ── Embedded in shell (dashboard tab) ──
    if (widget.embeddedInShell) {
      return ColoredBox(
        color: _P.bg,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mini header row (no SafeArea needed inside shell)
                Container(
                  color: _P.g1,
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Daily orders',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      ..._headerActions(),
                    ],
                  ),
                ),
                _filtersRow(),
                Expanded(child: _bodyContent(filtered)),
              ],
            ),
            Positioned(right: 16, bottom: 16, child: _fab()),
          ],
        ),
      );
    }

    // ── Standalone screen ──
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
        children: [
          _buildHeader(context),
          _buildSummaryRow(),
          _filtersRow(),
          Expanded(child: _bodyContent(filtered)),
        ],
        ),
      ),
      floatingActionButton: _fab(),
    );
  }
}

// ─── ORDER DETAIL SHEET ───────────────────────────────────────────────────────
class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({
    required this.order,
    required this.onAssign,
    required this.onStatusChange,
    required this.onWhatsApp,
  });

  final OrderModel order;
  final VoidCallback onAssign;
  final void Function(String status) onStatusChange;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final st = _ss(order.status);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BottomSheetHandle(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).padding.bottom + 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Customer hero ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _P.v100,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(order.customerName ?? order.customerId),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _P.v700,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _P.s900,
                            ),
                          ),
                          if (order.customerAddress != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              order.customerAddress!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _P.s500,
                              ),
                            ),
                          ],
                          if (order.slot != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Slot: ${order.slot}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _P.s500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _badge(st),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Assign button ──
                _filledBtn('Assign Delivery Boy', onAssign),

                const SizedBox(height: 14),

                // ── Status update label ──
                const Text(
                  'UPDATE STATUS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _P.v700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Status chips ──
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['processing', 'out_for_delivery', 'delivered'].map(
                    (s) {
                      final css = _ss(s);
                      return GestureDetector(
                        onTap: () => onStatusChange(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: css.bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: css.bdr, width: 0.5),
                          ),
                          child: Text(
                            css.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: css.txt,
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),

                const SizedBox(height: 12),

                // ── WhatsApp button ──
                _outlineBtn(
                  Icons.chat_bubble_outline_rounded,
                  'WhatsApp Customer',
                  onWhatsApp,
                  _P.greenTxt,
                  _P.greenBg,
                  _P.greenBdr,
                ),

                const SizedBox(height: 10),

                // ── Close ──
                _filledBtn('Close', () => Navigator.pop(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filledBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: _P.g1,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _P.g1.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );

  Widget _outlineBtn(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color fg,
    Color bg,
    Color bdr,
  ) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bdr, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── ASSIGN STAFF SHEET ───────────────────────────────────────────────────────
class _AssignStaffSheet extends StatelessWidget {
  const _AssignStaffSheet({
    required this.staff,
    required this.orderIds,
    required this.onAssigned,
  });

  final List<DeliveryStaffModel> staff;
  final List<String> orderIds;
  final VoidCallback onAssigned;

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          28,
          28,
          28,
          MediaQuery.of(context).padding.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: _P.v100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_off_outlined,
                color: _P.v500,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No delivery staff found.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _P.s700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add staff first.',
              style: TextStyle(fontSize: 12, color: _P.s500),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BottomSheetHandle(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Assign delivery person',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _P.s900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 14),
                ...staff.map(
                  (s) => GestureDetector(
                    onTap: () async {
                      try {
                        if (orderIds.length == 1) {
                          await OrderApi.assign(orderIds.first, s.id);
                        } else {
                          await OrderApi.assignBulk(orderIds, s.id);
                        }
                        if (context.mounted) {
                          AppSnackbar.success(context, 'Assigned');
                          onAssigned();
                        }
                      } catch (e) {
                        if (context.mounted) ErrorHandler.show(context, e);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _P.s100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _P.s200, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: _P.v100,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initials(s.name),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _P.v700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _P.s900,
                                  ),
                                ),
                                Text(
                                  s.phone,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _P.s500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: _P.v400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Initials helper ──────────────────────────────────────────────────────────
String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
}
