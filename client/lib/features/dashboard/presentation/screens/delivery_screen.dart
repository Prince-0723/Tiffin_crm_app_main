import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/whatsapp_helper.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../../delivery/data/delivery_api.dart';
import '../../../delivery/models/delivery_staff_model.dart';
import '../../../orders/data/order_api.dart';
import '../../../orders/models/order_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Static brand / semantic colors (never change between themes)
// ─────────────────────────────────────────────────────────────────────────────
class _B {
  // Brand violet
  static const primary    = Color(0xFF7B3FE4);
  static const v700       = Color(0xFF5B21B6);
  static const v600       = Color(0xFF7C3AED);
  static const v500       = Color(0xFF8B5CF6);
  static const v400       = Color(0xFFA78BFA);
  static const v200       = Color(0xFFDDD6FE);
  static const v100       = Color(0xFFEDE9FE);

  // Status semantic — always the same regardless of mode
  static const greenBg    = Color(0xFFF0FDF4);
  static const greenTxt   = Color(0xFF166534);
  static const greenBdr   = Color(0xFF86EFAC);
  static const amberBg    = Color(0xFFFFFBEB);
  static const amberTxt   = Color(0xFF92400E);
  static const amberBdr   = Color(0xFFFCD34D);
  static const blueBg     = Color(0xFFEFF6FF);
  static const blueTxt    = Color(0xFF1D4ED8);
  static const blueBdr    = Color(0xFFBFDBFE);
  static const redBg      = Color(0xFFFEF2F2);
  static const redTxt     = Color(0xFF991B1B);
  static const redBdr     = Color(0xFFFCA5A5);
  static const grayBg     = Color(0xFFF1F5F9);
  static const grayTxt    = Color(0xFF475569);
  static const grayBdr    = Color(0xFFCBD5E1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme-aware color extension on BuildContext
// ─────────────────────────────────────────────────────────────────────────────
extension _C on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  // Page / scaffold background
  Color get pageBg       => _isDark ? const Color(0xFF0E1020) : const Color(0xFFF0EBFF);

  // Card / surface
  Color get cardBg       => _isDark ? const Color(0xFF1B1F2E) : Colors.white;
  Color get surfaceBg    => _isDark ? const Color(0xFF141625) : Colors.white;

  // Borders / dividers
  Color get borderColor  => _isDark ? const Color(0xFF2F3347) : const Color(0xFFE2E8F0);
  Color get dividerColor => _isDark ? const Color(0xFF1E1B3A) : const Color(0xFFF1F5F9);

  // Text
  Color get txtPrimary   => _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get txtSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get txtHint      => _isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Search bar fill
  Color get searchFill   => _isDark ? const Color(0xFF1B1F2E) : const Color(0xFFF8FAFC);

  // Filter pill fill
  Color get pillBg       => _isDark ? const Color(0xFF1B1F2E) : Colors.white;

  // Bottom-sheet surface
  Color get sheetBg      => _isDark ? const Color(0xFF1B1F2E) : Colors.white;

  // Avatar background (initials circle)
  Color get avatarBg     => _B.v100;   // always light-violet — readable on dark too
  Color get avatarTxt    => _B.v700;

  // Staff card fill
  Color get staffCardBg  => _isDark ? const Color(0xFF141625) : const Color(0xFFF8FAFC);

  // Embedded header mini-bar
  Color get headerBg     => _B.primary; // same in both modes
}

// ─────────────────────────────────────────────────────────────────────────────
// Status style (semantic — unchanged across themes)
// ─────────────────────────────────────────────────────────────────────────────
class _StatusStyle {
  final Color bg, txt, bdr, accent, dot;
  final String label;
  const _StatusStyle({
    required this.bg, required this.txt, required this.bdr,
    required this.accent, required this.dot, required this.label,
  });
}

_StatusStyle _ss(String status, bool isDark) {
  switch (status.toLowerCase()) {
    case 'out_for_delivery':
      return _StatusStyle(
        bg: isDark ? const Color(0xFF1E293B) : _B.blueBg,
        txt: isDark ? const Color(0xFF60A5FA) : _B.blueTxt,
        bdr: isDark ? const Color(0xFF334155) : _B.blueBdr,
        accent: const Color(0xFF2563EB), dot: const Color(0xFF2563EB),
        label: 'Out for delivery',
      );
    case 'delivered':
      return _StatusStyle(
        bg: isDark ? const Color(0xFF0F2A1C) : _B.greenBg,
        txt: isDark ? const Color(0xFF4ADE80) : _B.greenTxt,
        bdr: isDark ? const Color(0xFF1F6B3F) : _B.greenBdr,
        accent: const Color(0xFF22C55E), dot: const Color(0xFF16A34A),
        label: 'Delivered',
      );
    case 'processing':
      return _StatusStyle(
        bg: isDark ? const Color(0xFF2D200A) : _B.amberBg,
        txt: isDark ? const Color(0xFFFBBF24) : _B.amberTxt,
        bdr: isDark ? const Color(0xFF7C5A18) : _B.amberBdr,
        accent: const Color(0xFFF59E0B), dot: const Color(0xFFD97706),
        label: 'Processing',
      );
    default:
      return _StatusStyle(
        bg: isDark ? const Color(0xFF1E293B) : _B.grayBg,
        txt: isDark ? const Color(0xFF94A3B8) : _B.grayTxt,
        bdr: isDark ? const Color(0xFF334155) : _B.grayBdr,
        accent: const Color(0xFF94A3B8), dot: const Color(0xFFCBD5E1),
        label: 'Pending',
      );
  }
}

// Status badge — semantic colors, no theme dependency needed
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

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────
enum _MealTimeFilter { all, breakfast, lunch, dinner }
enum _OrderSort { apiDefault, nameAz, nameZa }

// ─────────────────────────────────────────────────────────────────────────────
// DeliveryScreen
// ─────────────────────────────────────────────────────────────────────────────
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key, this.embeddedInShell = false});
  final bool embeddedInShell;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<OrderModel> _orders = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _statusFilter;
  DateTime? _filterDate;
  _MealTimeFilter _mealTimeFilter = _MealTimeFilter.all;
  _OrderSort? _sort = _OrderSort.apiDefault;
  final Set<String> _selectedIds = {};
  bool _bulkMode = false;
  bool _bulkStatusLoading = false;
  StreamSubscription<void>? _dailyOrdersSocketSub;

  static const List<String> _filterLabels = [
    'All', 'Pending', 'Processing', 'Out for delivery', 'Delivered',
  ];
  static const List<String?> _filterValues = [
    null, 'pending', 'processing', 'out_for_delivery', 'delivered',
  ];
  static const List<String> _mealTimeLabels = [
    'All', 'Breakfast', 'Lunch', 'Dinner',
  ];
  static const List<_MealTimeFilter> _mealTimeValues = [
    _MealTimeFilter.all, _MealTimeFilter.breakfast,
    _MealTimeFilter.lunch, _MealTimeFilter.dinner,
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _attachDailyOrdersSocket();
  }

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

  static String _dateToStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _hasCustomDate {
    if (_filterDate == null) return false;
    final now = DateTime.now();
    return _filterDate!.year != now.year ||
        _filterDate!.month != now.month ||
        _filterDate!.day != now.day;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dateStr = _filterDate != null ? _dateToStr(_filterDate!) : null;
      final list = await DeliveryApi.getAllDeliveries(date: dateStr);
      final visible = list.where((o) => o.status.toLowerCase() != 'cancelled').toList();
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
      _MealTimeFilter.lunch     => 'lunch',
      _MealTimeFilter.dinner    => 'dinner',
      _MealTimeFilter.all       => null,
    };
    return base.where((o) => _normalizeMealTime(o.mealTime) == wanted).toList();
  }

  List<OrderModel> get _searchedOrders {
    final q = _query.trim().toLowerCase();
    final base = _timeFilteredOrders;
    if (q.isEmpty) return base;
    return base.where((o) {
      final name  = (o.customerName  ?? '').toLowerCase();
      final phone = (o.customerPhone ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  static String _todayDateStr() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  Future<void> _generate() async {
    try {
      final dateStr = _todayDateStr();
      try { await OrderApi.generate(date: dateStr); }
      catch (_) { try { await OrderApi.process(date: dateStr); } catch (_) {} }
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
      await OrderApi.process(date: _todayDateStr());
      if (mounted) {
        AppSnackbar.success(context, 'Orders processed');
        await _load();
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  Future<void> _confirmBulkStatusUpdate(String apiStatus, String actionDescription) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) {
      AppSnackbar.error(context, 'Select orders first: tap Bulk, then tap each order to select.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor   = isDark ? const Color(0xFF1B1F2E) : Colors.white;
        final headColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final bodyColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

        return AlertDialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.layers_outlined, color: _B.v600, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bulk status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: headColor),
                ),
              ),
            ],
          ),
          content: Text(
            '$actionDescription for ${ids.length} selected order(s)?',
            style: TextStyle(fontSize: 13, color: bodyColor, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: bodyColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _B.v600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (ok != true || !mounted) return;

    setState(() => _bulkStatusLoading = true);
    try {
      final result = await OrderApi.updateStatusBulk(ids, apiStatus);
      if (!mounted) return;
      final parts = <String>[];
      if (result.updatedCount > 0)              parts.add('Updated ${result.updatedCount}');
      if (result.skippedSameStatus > 0)         parts.add('${result.skippedSameStatus} already had this status');
      if (result.skippedInvalidTransition > 0)  parts.add('${result.skippedInvalidTransition} skipped (cannot move from current status)');
      if (result.notFoundCount > 0)             parts.add('${result.notFoundCount} not found');
      if (result.failures.isNotEmpty) {
        final msg = result.failures.first.message;
        parts.add(result.failures.length == 1 ? 'Failed: $msg' : '${result.failures.length} failed ($msg…)');
      }
      final summary = parts.join('. ');
      AppSnackbar.success(context, summary.isEmpty ? 'No orders changed' : summary);
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
        onAssign: () => _openAssignSheet(ctx, [order.id], closeParentSheetOnAssigned: true),
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
          if (closeParentSheetOnAssigned && sheetContext.mounted) Navigator.pop(sheetContext);
          if (mounted) setState(() { _bulkMode = false; _selectedIds.clear(); });
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

  int _count(String? status) => status == null
      ? _orders.length
      : _orders.where((o) => o.status == status).length;

  // ── Header (standalone mode) ──────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _B.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.maybePop(context),
              ),
              const Expanded(
                child: Text(
                  'Daily Deliveries',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3),
                ),
              ),
              ..._headerActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Container(
      color: _B.primary,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          _summaryTile('${_count(null)}',                'Total'),
          const SizedBox(width: 8),
          _summaryTile('${_count("out_for_delivery")}',  'Out for delivery'),
          const SizedBox(width: 8),
          _summaryTile('${_count("pending")}',           'Pending'),
          const SizedBox(width: 8),
          _summaryTile('${_count("delivered")}',         'Done'),
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
          Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 1),
          Text(label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    ),
  );

  List<Widget> _headerActions() => [
    _hdrBtn(Icons.playlist_add,                 _loading ? null : _generate, 'Generate'),
    const SizedBox(width: 6),
    _hdrBtn(Icons.check_circle_outline_rounded, _loading ? null : _process,  'Process'),
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
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Icon(
          icon,
          color: onTap == null ? Colors.white.withValues(alpha: 0.4) : Colors.white,
          size: 15,
        ),
      ),
    ),
  );

  // ── Filter pills ──────────────────────────────────────────────────────────

  String _sortLabel() {
    final label = switch (_sort ?? _OrderSort.apiDefault) {
      _OrderSort.apiDefault => 'Default',
      _OrderSort.nameAz     => 'Name A–Z',
      _OrderSort.nameZa     => 'Name Z–A',
    };
    return 'Sort By ($label)';
  }

  String _statusLabel() {
    final i = _filterValues.indexOf(_statusFilter);
    return 'Status (${(i >= 0) ? _filterLabels[i] : _filterLabels.first})';
  }

  String _mealLabel() {
    final i = _mealTimeValues.indexOf(_mealTimeFilter);
    return 'Meal (${(i >= 0) ? _mealTimeLabels[i] : _mealTimeLabels.first})';
  }

  String _dateLabel() {
    final d   = _filterDate ?? DateTime.now();
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    return 'Date (${isToday ? 'Today' : DateFormat('d MMM yyyy', 'en').format(d)})';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 500)),
      lastDate:  DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _filterDate = DateTime(picked.year, picked.month, picked.day));
    await _load();
  }

  void _clearDate() {
    setState(() => _filterDate = null);
    _load();
  }

  Widget _dateFilterPill() {
    return Builder(builder: (context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.pillBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dateLabel(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.txtPrimary),
                ),
                const SizedBox(width: 6),
                Icon(
                  _hasCustomDate ? Icons.event_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 16, color: context.txtHint,
                ),
              ],
            ),
          ),
          if (_hasCustomDate) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _clearDate,
              child: Icon(Icons.close_rounded, size: 15, color: context.txtHint),
            ),
          ],
        ],
      ),
    ));
  }

  Widget _dropdownPill({required String label, required VoidCallback onTap}) {
    return Builder(builder: (context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.pillBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.txtPrimary),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: context.txtHint),
          ],
        ),
      ),
    ));
  }

  // ── Bottom-sheet helpers ──────────────────────────────────────────────────

  Widget _sheetContainer({required Widget child}) {
    return Builder(builder: (context) => Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context._isDark ? 0.35 : 0.08),
            blurRadius: 18, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
    ));
  }

  Widget _sheetHeader(BuildContext ctx, String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                style: TextStyle(color: ctx.txtPrimary, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, size: 20),
              color: ctx.txtSecondary,
            ),
          ],
        ),
      ),
      Container(height: 1, color: ctx.borderColor),
    ],
  );

  Widget _sheetRadioItem<T>(
    BuildContext ctx,
    T v,
    T selected,
    String label,
    VoidCallback onTap,
  ) {
    final sel = selected == v;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              sel ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: sel ? _B.primary : ctx.txtHint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ctx.txtPrimary),
              ),
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
      builder: (ctx) => SafeArea(
        child: _sheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHeader(ctx, 'Sort By'),
              _sheetRadioItem(ctx, _OrderSort.apiDefault, _sort ?? _OrderSort.apiDefault, 'Default',
                () { Navigator.pop(ctx); setState(() => _sort = _OrderSort.apiDefault); }),
              Container(height: 1, color: ctx.borderColor),
              _sheetRadioItem(ctx, _OrderSort.nameAz, _sort ?? _OrderSort.apiDefault, 'Name A–Z',
                () { Navigator.pop(ctx); setState(() => _sort = _OrderSort.nameAz); }),
              Container(height: 1, color: ctx.borderColor),
              _sheetRadioItem(ctx, _OrderSort.nameZa, _sort ?? _OrderSort.apiDefault, 'Name Z–A',
                () { Navigator.pop(ctx); setState(() => _sort = _OrderSort.nameZa); }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStatusSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: _sheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHeader(ctx, 'Status'),
              ...List.generate(_filterLabels.length, (i) => Column(
                children: [
                  _sheetRadioItem(ctx, _filterValues[i], _statusFilter, _filterLabels[i],
                    () { Navigator.pop(ctx); setState(() => _statusFilter = _filterValues[i]); }),
                  if (i != _filterLabels.length - 1) Container(height: 1, color: ctx.borderColor),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMealSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: _sheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHeader(ctx, 'Meal'),
              ...List.generate(_mealTimeLabels.length, (i) => Column(
                children: [
                  _sheetRadioItem(ctx, _mealTimeValues[i], _mealTimeFilter, _mealTimeLabels[i],
                    () { Navigator.pop(ctx); setState(() => _mealTimeFilter = _mealTimeValues[i]); }),
                  if (i != _mealTimeLabels.length - 1) Container(height: 1, color: ctx.borderColor),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bulk actions row ──────────────────────────────────────────────────────

  Widget _bulkStatusActionsRow() {
    Widget chip(String label, String apiStatus, String confirmBlurb) {
      final canRun = !_bulkStatusLoading && _selectedIds.isNotEmpty;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton(
          onPressed: canRun ? () => _confirmBulkStatusUpdate(apiStatus, confirmBlurb) : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? _B.v400 : _B.v700,
            side: BorderSide(color: isDark ? _B.v700 : _B.v200, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      );
    }

    return Builder(builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _selectedIds.isEmpty
                  ? 'Bulk status (select orders)'
                  : 'Bulk status (${_selectedIds.length} selected)',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: _selectedIds.isEmpty ? context.txtHint : context.txtSecondary,
                letterSpacing: 0.4,
              ),
            ),
            if (_bulkStatusLoading) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(color: _B.v600, strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('Mark Selected Processing',       'processing',       'Mark selected orders as Processing'),
              chip('Mark Selected Out for Delivery', 'out_for_delivery', 'Mark selected orders as Out for delivery'),
              chip('Mark Selected Delivered',        'delivered',        'Mark selected orders as Delivered'),
            ],
          ),
        ),
      ],
    ));
  }

  // ── Filters row ───────────────────────────────────────────────────────────

  Widget _filtersRow() {
    return Builder(builder: (context) => Container(
      color: context.surfaceBg,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        children: [
          _bulkStatusActionsRow(),
          const SizedBox(height: 10),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: context.searchFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 16, color: context.txtHint),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 13, color: context.txtPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search name, phone…',
                      hintStyle: TextStyle(fontSize: 13, color: context.txtHint),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () { _searchController.clear(); setState(() => _query = ''); },
                    child: Icon(Icons.close_rounded, size: 15, color: context.txtHint),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _dateFilterPill(),
                const SizedBox(width: 8),
                _dropdownPill(label: _sortLabel(),   onTap: _openSortSheet),
                const SizedBox(width: 8),
                _dropdownPill(label: _statusLabel(), onTap: _openStatusSheet),
                const SizedBox(width: 8),
                _dropdownPill(label: _mealLabel(),   onTap: _openMealSheet),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _bodyContent(List<OrderModel> filtered) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _B.v600, strokeWidth: 2));
    }

    return Builder(builder: (context) => RefreshIndicator(
      color: _B.v600,
      onRefresh: _load,
      child: filtered.isEmpty
          ? ListView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: const BoxDecoration(color: _B.v100, shape: BoxShape.circle),
                        child: const Icon(Icons.delivery_dining_outlined, color: _B.v500, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text('No orders found',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.txtSecondary),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _generate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(color: _B.primary, borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text("Generate today's orders",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
              padding: EdgeInsets.fromLTRB(0, 6, 0, MediaQuery.of(context).padding.bottom + 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final order    = filtered[index];
                final st       = _ss(order.status, context._isDark);
                final selected = _selectedIds.contains(order.id);
                final isLast   = index == filtered.length - 1;
                final name     = (order.customerName?.trim().isNotEmpty == true)
                    ? order.customerName!.trim() : order.customerId;
                final slot = order.slot?.trim();
                final time = (slot != null && slot.isNotEmpty)
                    ? slot : (_normalizeMealTime(order.mealTime) ?? '').trim();
                final staff = order.deliveryStaffName?.trim();
                final parts = <String>[
                  if (time.isNotEmpty) '${time[0].toUpperCase()}${time.substring(1)}',
                  if (staff != null && staff.isNotEmpty) staff,
                ];
                final subtitle = parts.join('  ·  ');

                return RepaintBoundary(
                  child: Material(
                    color: context.cardBg,
                    child: InkWell(
                      onTap: () => _bulkMode ? _toggleSelect(order) : _showOrderSheet(order),
                      onLongPress: _bulkMode ? null : () => setState(() {
                        _bulkMode = true;
                        _selectedIds.add(order.id);
                      }),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isLast ? Colors.transparent : context.dividerColor,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      if (_bulkMode)
                                        GestureDetector(
                                          onTap: () => _toggleSelect(order),
                                          child: Container(
                                            width: 22, height: 22,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: selected ? _B.primary : context.txtHint, width: 2,
                                              ),
                                              color: selected ? _B.primary : Colors.transparent,
                                            ),
                                            child: selected
                                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                                : null,
                                          ),
                                        )
                                      else
                                        const SizedBox.shrink(),
                                      if (_bulkMode) const SizedBox(width: 12),
                                      Container(
                                        width: 40, height: 40,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: context.avatarBg),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _initials(name),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.avatarTxt),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (_bulkMode && selected) ...[
                                                  const Icon(Icons.check_circle_rounded, size: 16, color: _B.primary),
                                                  const SizedBox(width: 6),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: TextStyle(
                                                      fontSize: 14, fontWeight: FontWeight.w800,
                                                      color: (_bulkMode && selected) ? _B.primary : context.txtPrimary,
                                                    ),
                                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (subtitle.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                subtitle,
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.txtSecondary),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
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
    ));
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _fab() {
    if (_bulkMode && _selectedIds.isNotEmpty) {
      return FloatingActionButton.extended(
        heroTag: 'delivery_fab_assign',
        onPressed: () => _openAssignSheet(context, _selectedIds.toList(), closeParentSheetOnAssigned: false),
        backgroundColor: _B.primary,
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = [..._searchedOrders];
    switch (_sort ?? _OrderSort.apiDefault) {
      case _OrderSort.apiDefault: break;
      case _OrderSort.nameAz:
        filtered.sort((a, b) =>
          (a.customerName ?? '').trim().toLowerCase()
              .compareTo((b.customerName ?? '').trim().toLowerCase()));
        break;
      case _OrderSort.nameZa:
        filtered.sort((a, b) =>
          (b.customerName ?? '').trim().toLowerCase()
              .compareTo((a.customerName ?? '').trim().toLowerCase()));
        break;
    }

    if (widget.embeddedInShell) {
      return ColoredBox(
        color: context.pageBg,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: context.headerBg,
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Daily orders',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2),
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

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        top: false, bottom: true,
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

// ─────────────────────────────────────────────────────────────────────────────
// _OrderDetailSheet
// ─────────────────────────────────────────────────────────────────────────────
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
    final isDark = context._isDark;
    final st = _ss(order.status, isDark);

    return Container(
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BottomSheetHandle(),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Customer hero
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: context.avatarBg),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(order.customerName ?? order.customerId),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.avatarTxt),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName ?? order.customerId,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.txtPrimary),
                          ),
                          if (order.customerAddress != null) ...[
                            const SizedBox(height: 2),
                            Text(order.customerAddress!,
                              style: TextStyle(fontSize: 11, color: context.txtSecondary)),
                          ],
                          if (order.slot != null) ...[
                            const SizedBox(height: 2),
                            Text('Slot: ${order.slot}',
                              style: TextStyle(fontSize: 11, color: context.txtSecondary)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _badge(st),
                  ],
                ),

                const SizedBox(height: 20),
                _filledBtn('Assign Delivery Boy', onAssign),
                const SizedBox(height: 14),

                Text(
                  'UPDATE STATUS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? _B.v400 : _B.v700, letterSpacing: 0.6),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ['processing', 'out_for_delivery', 'delivered'].map((s) {
                    final css = _ss(s, isDark);
                    return GestureDetector(
                      onTap: () => onStatusChange(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: css.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: css.bdr, width: 0.5),
                        ),
                        child: Text(css.label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: css.txt)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),
                _outlineBtn(
                  Icons.chat_bubble_outline_rounded,
                  'WhatsApp Customer',
                  onWhatsApp,
                  isDark ? const Color(0xFF4ADE80) : _B.greenTxt,
                  isDark ? const Color(0xFF0F2A1C) : _B.greenBg,
                  isDark ? const Color(0xFF1F6B3F) : _B.greenBdr,
                ),
                const SizedBox(height: 10),
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
        color: _B.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: _B.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
    ),
  );

  Widget _outlineBtn(IconData icon, String label, VoidCallback onTap, Color fg, Color bg, Color bdr) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bdr, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// _AssignStaffSheet
// ─────────────────────────────────────────────────────────────────────────────
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
        decoration: BoxDecoration(
          color: context.sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(28, 28, 28, MediaQuery.of(context).padding.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(color: _B.v100, shape: BoxShape.circle),
              child: const Icon(Icons.person_off_outlined, color: _B.v500, size: 26),
            ),
            const SizedBox(height: 14),
            Text('No delivery staff found.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.txtSecondary)),
            const SizedBox(height: 4),
            Text('Add staff first.',
              style: TextStyle(fontSize: 12, color: context.txtHint)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BottomSheetHandle(),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Assign delivery person',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: context.txtPrimary, letterSpacing: -0.2),
                ),
                const SizedBox(height: 14),
                ...staff.map((s) => GestureDetector(
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.staffCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: context.avatarBg, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(s.name),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.avatarTxt),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.txtPrimary)),
                              Text(s.phone,
                                style: TextStyle(fontSize: 11, color: context.txtSecondary)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: _B.v400, size: 20),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
}