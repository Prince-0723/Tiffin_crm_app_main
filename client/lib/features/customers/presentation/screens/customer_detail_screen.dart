import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/router/app_routes.dart';
// ignore: unused_import
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/location_helper.dart';
import '../../../../core/utils/subscription_calendar_days.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import '../../../dashboard/overview_dashboard_refresh_signal.dart';
import '../../../../core/utils/whatsapp_helper.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../../../models/customer_model.dart';
import '../../../../services/customer_detail_service.dart';
import '../../data/customer_api.dart';
import '../../utils/customer_location_payload.dart';
import '../widgets/customer_location_pick_sheet.dart';
import 'tiffin_collection_history_screen.dart';
import '../widgets/customer_tiffin_nav_row.dart';
import '../../../subscriptions/data/subscription_api.dart';
import '../../../subscriptions/models/subscription_model.dart';
import '../../../payments/presentation/widgets/daily_receipt_sheet.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _P {
  static const g1 = Color(0xFF7B3FE4);
  static const g2 = Color(0xFFA855F7);
  static const v700 = Color(0xFF5B21B6);
  static const v600 = Color(0xFF7C3AED);
  static const v500 = Color(0xFF8B5CF6);
  static const v300 = Color(0xFFC4B5FD);
  static const v200 = Color(0xFFDDD6FE);
  static const v100 = Color(0xFFEDE9FE);
  static const v50 = Color(0xFFF5F3FF);
  static const bg = Color(0xFFF0EBFF);
  static const s900 = Color(0xFF0F172A);
  // ignore: unused_field
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
  static const redBg = Color(0xFFFEF2F2);
  static const redTxt = Color(0xFF991B1B);
  static const redBdr = Color(0xFFFCA5A5);
  static const grayBg = Color(0xFFF1F5F9);
  static const grayTxt = Color(0xFF475569);
  static const grayBdr = Color(0xFFCBD5E1);
  static const blueBg = Color(0xFFEFF6FF);
  static const blueTxt = Color(0xFF1D4ED8);
  static const blueBdr = Color(0xFFBFDBFE);
}

// ─── Status helpers ───────────────────────────────────────────────────────────
class _StatusStyle {
  final Color bg, txt, bdr;
  final String label;
  const _StatusStyle({
    required this.bg,
    required this.txt,
    required this.bdr,
    required this.label,
  });
}

_StatusStyle _statusStyle(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return const _StatusStyle(
        bg: _P.greenBg,
        txt: _P.greenTxt,
        bdr: _P.greenBdr,
        label: 'Active',
      );
    case 'inactive':
      return const _StatusStyle(
        bg: _P.redBg,
        txt: _P.redTxt,
        bdr: _P.redBdr,
        label: 'Inactive',
      );
    case 'paused':
      return const _StatusStyle(
        bg: _P.amberBg,
        txt: _P.amberTxt,
        bdr: _P.amberBdr,
        label: 'Paused',
      );
    case 'expired':
      return const _StatusStyle(
        bg: _P.redBg,
        txt: _P.redTxt,
        bdr: _P.redBdr,
        label: 'Expired',
      );
    case 'cancelled':
      return const _StatusStyle(
        bg: _P.grayBg,
        txt: _P.grayTxt,
        bdr: _P.grayBdr,
        label: 'Cancelled',
      );
    case 'out_for_delivery':
      return const _StatusStyle(
        bg: _P.blueBg,
        txt: _P.blueTxt,
        bdr: _P.blueBdr,
        label: 'Out for delivery',
      );
    default:
      return const _StatusStyle(
        bg: _P.grayBg,
        txt: _P.grayTxt,
        bdr: _P.grayBdr,
        label: 'Unknown',
      );
  }
}

Widget _badge(_StatusStyle st) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
  decoration: BoxDecoration(
    color: st.bg,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: st.bdr, width: 0.5),
  ),
  child: Text(
    st.label,
    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: st.txt),
  ),
);

Color _avatarColor(String name) {
  const colors = [
    Color(0xFF0D9488), // teal
    Color(0xFF0891B2), // cyan
    Color(0xFF2563EB), // blue
    Color(0xFF7C3AED), // violet
    Color(0xFF059669), // emerald
    Color(0xFFD97706), // amber
    Color(0xFFDC2626), // red
    Color(0xFF7C3AED), // purple
  ];
  if (name.isEmpty) return colors[0];
  return colors[name.codeUnitAt(0) % colors.length];
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1)
    // ignore: curly_braces_in_flow_control_structures
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customer});
  final CustomerModel customer;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  // ── ALL LOGIC UNCHANGED ──
  CustomerModel? _customer;
  List<SubscriptionModel> _subscriptions = [];
  bool _isLoading = true;
  bool _sendingWalletReminder = false;
  bool _savingCustomerLocation = false;
  int _tiffinRowGeneration = 0;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final c = await CustomerApi.getById(widget.customer.id);

      // SubscriptionApi.list always returns Map<String,dynamic>
      final Map<String, dynamic> res = await SubscriptionApi.list(
        customerId: widget.customer.id,
      );

      final inner = res['data'];
      List<dynamic> rawList = [];
      if (inner is Map<String, dynamic>) {
        rawList = (inner['data'] as List?) ?? [];
      } else if (inner is List) {
        rawList = inner;
      }
      final parsedSubs = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => SubscriptionModel.fromJson(e))
          .toList();

      if (mounted) {
        setState(() {
          _customer = c;
          _subscriptions = parsedSubs;
          _tiffinRowGeneration++;
        });
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreditWalletSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreditWalletSheet(
        customerId: _customer!.id,
        onSuccess: () {
          Navigator.pop(ctx);
          AppSnackbar.success(context, 'Wallet credited');
          _load();
        },
        onError: (e) => ErrorHandler.show(ctx, e),
      ),
    );
  }

  Future<void> _openDailyReceipt() async {
    final c = _customer;
    if (c == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DailyReceiptSheet(
        key: ValueKey<String>('daily-receipt-${c.id}-${picked.toIso8601String()}'),
        customerId: c.id,
        customerName: c.name,
        initialDate: picked,
      ),
    );
  }

  Future<void> _sendWalletReminder() async {
    final c = _customer;
    if (c == null) return;
    setState(() => _sendingWalletReminder = true);
    try {
      final data = await CustomerDetailService.notifyWalletReminder(c.id);
      if (!mounted) return;
      final msg = data['whatsappMessage']?.toString() ??
          WhatsAppHelper.lowBalanceMessage(
            c.name,
            (data['walletBalance'] as num?)?.toDouble() ??
                c.effectiveWalletBalance,
          );
      final phone =
          (c.whatsapp?.isNotEmpty == true) ? c.whatsapp! : c.phone;
      if (phone.isEmpty) {
        AppSnackbar.error(context, 'No phone number');
        return;
      }
      final ok = await WhatsAppHelper.openWithMessage(phone, msg);
      if (!mounted) return;
      if (ok) {
        AppSnackbar.success(context, 'Reminder sent (notification + WhatsApp)');
      } else {
        AppSnackbar.success(
          context,
          'In-app reminder sent. Open WhatsApp manually if needed.',
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _sendingWalletReminder = false);
    }
  }

  bool _hasCustomerMapLocation(CustomerModel c) {
    final loc = c.location;
    if (loc == null) return false;
    return hasValidCustomerMapPin(loc.lat, loc.lng);
  }

  Future<void> _openCustomerLocationPicker(CustomerModel c) async {
    final initial = c.location;
    final hasPin =
        initial != null && (initial.lat != 0 || initial.lng != 0);
    final initialLatLng = hasPin ? LatLng(initial.lat, initial.lng) : null;
    final result = await showCustomerLocationPickSheet(
      context,
      initialPosition: initialLatLng,
      initialAddress: c.address,
    );
    if (result == null || !mounted) return;
    setState(() => _savingCustomerLocation = true);
    try {
      await CustomerApi.update(
        c.id,
        buildCustomerLocationUpdateBody(
          lat: result.lat,
          lng: result.lng,
          address: result.address,
        ),
      );
      if (!mounted) return;
      AppSnackbar.success(context, 'Location saved');
      await _load();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _savingCustomerLocation = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Customer',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _P.s900,
          ),
        ),
        content: Text(
          'Delete ${_customer?.name ?? widget.customer.name}? This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: _P.s600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _P.s600, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await CustomerApi.delete(widget.customer.id);
                DeliveryTrackingSocket.instance.notifyDailyOrdersChanged();
                overviewDashboardTabSelectedTick.value++;
                if (mounted) {
                  AppSnackbar.success(context, 'Customer deleted');
                  context.pop();
                }
              } catch (e) {
                if (mounted) ErrorHandler.show(context, e);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _P.redBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _P.redBdr, width: 0.5),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: _P.redTxt,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = _customer ?? widget.customer;
    SubscriptionModel? activeSubscription;
    for (final subscription in _subscriptions) {
      final status = subscription.status.toLowerCase();
      if ((status == 'active' || status == 'paused') &&
          subscription.endDate.isAfter(DateTime.now())) {
        if (activeSubscription == null ||
            subscription.endDate.isAfter(activeSubscription.endDate)) {
          activeSubscription = subscription;
        }
      }
    }
    final subscriptionBalance =
        activeSubscription?.remainingBalance ??
        activeSubscription?.totalAmount ??
        activeSubscription?.paidAmount ??
        0;

    if (_isLoading && _customer == null) {
      return Scaffold(
        backgroundColor: _P.bg,
        appBar: AppBar(
          backgroundColor: _P.g1,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            c.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: _P.v600, strokeWidth: 2),
        ),
      );
    }

    final isLowBalance = c.effectiveWalletBalance < 100;

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        slivers: [
          // ── Violet AppBar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: _P.g1,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text(
              'Customer Detail',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () async {
                  await context.push(AppRoutes.editCustomer, extra: c);
                  _load(); // edit se wapas aane ke baad refresh
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: _isLoading ? null : _load,
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Profile hero row ──
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _avatarColor(c.name),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _avatarColor(c.name).withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(c.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Name + phone + area
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _P.s900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              c.phone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _P.s500,
                              ),
                            ),
                            if (c.area?.isNotEmpty == true) ...[
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _P.v50,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: _P.v200,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  c.area!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _P.v700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Status badge
                      _badge(_statusStyle(c.status)),
                    ],
                  ),
                ),

                // ── Wallet card ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_P.g1, _P.g2],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Wallet balance',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.75),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${c.effectiveWalletBalance.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (isLowBalance) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Low balance',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _showCreditWalletSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: const Text(
                                  '+ Add Money',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Subscription remaining',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '₹${subscriptionBalance.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                _sectionLabel('Tiffin boxes to collect'),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomerTiffinNavRow(
                        key: ValueKey<String>(
                          'tiffin-row-${c.id}-$_tiffinRowGeneration',
                        ),
                        customerId: c.id,
                        customerName: c.name,
                        margin: EdgeInsets.zero,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    TiffinCollectionHistoryScreen(
                                  customerId: c.id,
                                  customerName: c.name,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.calendar_month_rounded,
                              size: 18),
                          label: const Text('History & calendar'),
                          style: TextButton.styleFrom(
                            foregroundColor: _P.v600,
                            padding: const EdgeInsets.only(top: 2, bottom: 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Contact info section ──
                _sectionLabel('Contact info'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _P.s200, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Phone', c.phone),
                      if (c.whatsapp?.isNotEmpty == true)
                        _infoRow('WhatsApp', c.whatsapp!),
                      if (c.email?.isNotEmpty == true)
                        _infoRow('Email', c.email!),
                      if (c.address?.isNotEmpty == true)
                        _infoRow('Address', c.address!),
                      if (c.landmark?.isNotEmpty == true)
                        _infoRow('Landmark', c.landmark!),
                      if (c.area?.isNotEmpty == true) _infoRow('Area', c.area!),
                      if (c.notes?.isNotEmpty == true)
                        _infoRow('Notes', c.notes!, isLast: true),
                      if (c.tags?.isNotEmpty == true)
                        _infoRow('Tags', c.tags!.join(', '), isLast: true),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Location / zone ──
                _sectionLabel('Location / zone'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _P.s200, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_savingCustomerLocation)
                        const LinearProgressIndicator(
                          minHeight: 2,
                          color: _P.v600,
                        ),
                      _infoRow(
                        'Delivery zone',
                        c.zoneName?.trim().isNotEmpty == true
                            ? c.zoneName!.trim()
                            : '—',
                      ),
                      if (!_hasCustomerMapLocation(c))
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(14, 4, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Zone Not Set',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _P.s600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () => _openCustomerLocationPicker(c),
                                icon: const Icon(
                                  Icons.add_location_alt_outlined,
                                  size: 18,
                                ),
                                label: const Text('Set location'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _P.g1,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      tooltip: 'Open in Google Maps',
                                      onPressed: () =>
                                          LocationHelper.openGoogleMaps(
                                        c.location!.lat,
                                        c.location!.lng,
                                      ),
                                      icon: Icon(
                                        Icons.location_pin,
                                        color: _P.v600,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.address?.trim().isNotEmpty ==
                                                    true
                                                ? c.address!.trim()
                                                : 'Pinned location',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _P.s900,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${c.location!.lat.toStringAsFixed(6)}, ${c.location!.lng.toStringAsFixed(6)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: _P.s500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 0,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : () =>
                                              _openCustomerLocationPicker(c),
                                      icon: const Icon(
                                        Icons.edit_location_alt_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Edit location'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _P.v600,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          LocationHelper.openGoogleMaps(
                                        c.location!.lat,
                                        c.location!.lng,
                                      ),
                                      icon: const Icon(
                                        Icons.map_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Google Maps'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _P.s600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (activeSubscription != null &&
                    activeSubscription.payLater == true) ...[
                  _sectionLabel('Plan credit'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _P.s200, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                          'Credit limit',
                          '₹${(activeSubscription.creditLimit ?? activeSubscription.totalAmount ?? 0).toStringAsFixed(0)}',
                        ),
                        if (activeSubscription.consumptionExposure != null)
                          _infoRow(
                            'Meal exposure',
                            '₹${activeSubscription.consumptionExposure!.toStringAsFixed(0)}',
                          ),
                        if (activeSubscription.creditHeadroom != null)
                          _infoRow(
                            'Credit headroom',
                            '₹${activeSubscription.creditHeadroom!.toStringAsFixed(0)}',
                          ),
                        _infoRow(
                          'Due on plan',
                          '₹${activeSubscription.amountDueOnPlan.toStringAsFixed(0)}',
                        ),
                        _infoRow(
                          'Pay by',
                          activeSubscription.paymentDueDate != null
                              ? DateFormat.yMMMd().format(
                                  activeSubscription.paymentDueDate!,
                                )
                              : '—',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Action buttons ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      // Row 1: Call + WhatsApp + Credit Wallet
                      Row(
                        children: [
                          Expanded(
                            child: _actionBtn(
                              icon: Icons.phone_rounded,
                              label: 'Call',
                              fg: _P.redTxt,
                              bg: _P.redBg,
                              bdr: _P.redBdr,
                              onTap: () async {
                                final ok =
                                    await WhatsAppHelper.callPhone(c.phone);
                                if (!mounted) return;
                                if (!ok) {
                                  AppSnackbar.error(
                                    context,
                                    'Could not open phone dialer',
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionBtn(
                              icon: Icons.chat_rounded,
                              label: 'WhatsApp',
                              fg: _P.greenTxt,
                              bg: _P.greenBg,
                              bdr: _P.greenBdr,
                              onTap: () => WhatsAppHelper.openChat(
                                c.whatsapp ?? c.phone,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionBtn(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Wallet',
                              fg: _P.v700,
                              bg: _P.v50,
                              bdr: _P.v300,
                              onTap: _showCreditWalletSheet,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7C3AED),
                            side: const BorderSide(
                              color: Color(0xFF7C3AED),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _openDailyReceipt,
                          icon: const Icon(Icons.receipt_outlined, size: 18),
                          label: const Text(
                            'Daily Receipt',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      _actionBtn(
                        icon: Icons.notifications_outlined,
                        label: _sendingWalletReminder
                            ? 'Sending reminder…'
                            : 'Send wallet reminder',
                        fg: _P.amberTxt,
                        bg: _P.amberBg,
                        bdr: _P.amberBdr,
                        onTap: _sendingWalletReminder ? () {} : _sendWalletReminder,
                        fullWidth: true,
                      ),
                      const SizedBox(height: 10),

                      // Delete
                      _actionBtn(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete Customer',
                        fg: _P.redTxt,
                        bg: _P.redBg,
                        bdr: _P.redBdr,
                        onTap: _confirmDelete,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Subscription history ──
                _sectionLabel('Subscription history'),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _P.v600,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (_subscriptions.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _P.s200, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: _P.v100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: _P.v500,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'No subscriptions yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: _P.s500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: _subscriptions.map((s) {
                        final st = _statusStyle(s.status);
                        final isDone =
                            s.status.toLowerCase() == 'expired' ||
                            s.status.toLowerCase() == 'cancelled';
                        final totalDays = totalDaysInclusiveIST(
                          s.startDate,
                          s.endDate,
                        );
                        final remaining = remainingDaysInclusiveIST(
                          s.startDate,
                          s.endDate,
                        );
                        final progress = totalDays > 0
                            ? (1 - (remaining / totalDays)).clamp(0.0, 1.0)
                            : 1.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _P.s200, width: 0.5),
                          ),
                          padding: const EdgeInsets.all(13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.planName ?? s.planId,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _P.s900,
                                      ),
                                    ),
                                  ),
                                  _badge(st),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s.startDate.day}/${s.startDate.month}/${s.startDate.year} – ${s.endDate.day}/${s.endDate.month}/${s.endDate.year}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _P.s500,
                                ),
                              ),
                              if (s.deliverySlot != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _P.v50,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: _P.v200,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        s.deliverySlot!,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: _P.v700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (!isDone) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor: _P.v200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      st.bdr,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 32),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared section label ──
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: _P.v700,
        letterSpacing: 0.7,
      ),
    ),
  );

  // ── Info row ──
  Widget _infoRow(String label, String value, {bool isLast = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: _P.s200, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: _P.s500),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _P.s900,
                ),
              ),
            ),
          ],
        ),
      );

  // ── Action button ──
  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color fg,
    required Color bg,
    required Color bdr,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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

// ─── Credit Wallet Sheet ──────────────────────────────────────────────────────
class _CreditWalletSheet extends StatefulWidget {
  const _CreditWalletSheet({
    required this.customerId,
    required this.onSuccess,
    required this.onError,
  });
  final String customerId;
  final VoidCallback onSuccess;
  final void Function(dynamic) onError;

  @override
  State<_CreditWalletSheet> createState() => _CreditWalletSheetState();
}

class _CreditWalletSheetState extends State<_CreditWalletSheet> {
  // ── ALL LOGIC UNCHANGED ──
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  /// Prevents duplicate POSTs when the user double/triple-taps "Add Money".
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitWallet() async {
    if (_submitting) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AppSnackbar.error(context, 'Enter valid amount');
      return;
    }
    // Lock synchronously before any await so rapid taps cannot enqueue 3 requests.
    _submitting = true;
    setState(() {});
    try {
      await CustomerApi.creditWallet(
        widget.customerId,
        amount: amount,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) widget.onSuccess();
    } catch (e) {
      if (mounted) widget.onError(e);
    } finally {
      _submitting = false;
      if (mounted) setState(() {});
    }
  }

  InputDecoration _inputDeco(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(fontSize: 12, color: _P.s500),
    hintStyle: const TextStyle(fontSize: 12, color: _P.s400),
    filled: true,
    fillColor: _P.s100,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _P.s200, width: 0.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _P.v500, width: 1),
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
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).padding.bottom + 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BottomSheetHandle(),

            const Text(
              'Credit Wallet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _P.s900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 18),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 13,
                color: _P.s900,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDeco('Amount (₹)', hint: '0'),
            ),
            const SizedBox(height: 14),

            // Payment method label
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _P.v700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),

            // Payment chips
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: ['cash', 'razorpay'].map((m) {
                final sel = _paymentMethod == m;
                final label = m == 'razorpay' ? 'Razorpay' : 'Cash';
                return GestureDetector(
                  onTap: () => setState(() => _paymentMethod = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? _P.g1 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? _P.g1 : _P.s300,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : _P.s600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13, color: _P.s900),
              decoration: _inputDeco('Notes (optional)'),
            ),
            const SizedBox(height: 24),

            // Submit
            FilledButton(
              onPressed: _submitting ? null : _submitWallet,
              style: FilledButton.styleFrom(
                backgroundColor: _P.g1,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _P.g1.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Add Money',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
