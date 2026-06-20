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

// ─── Semantic status colours (same values, used only for status chips) ────────
// These are intentionally NOT theme-aware because status chips carry semantic
// meaning (green = active, red = inactive, etc.) that must stay consistent in
// both light and dark mode. Only the chip background is lightened/opacified.
class _S {
  // green
  static const greenBg  = Color(0xFFF0FDF4);
  static const greenTxt = Color(0xFF166534);
  static const greenBdr = Color(0xFF86EFAC);
  // amber
  static const amberBg  = Color(0xFFFFFBEB);
  static const amberTxt = Color(0xFF92400E);
  static const amberBdr = Color(0xFFFCD34D);
  // red
  static const redBg  = Color(0xFFFEF2F2);
  static const redTxt = Color(0xFF991B1B);
  static const redBdr = Color(0xFFFCA5A5);
  // gray
  static const grayBg  = Color(0xFFF1F5F9);
  static const grayTxt = Color(0xFF475569);
  static const grayBdr = Color(0xFFCBD5E1);
  // blue
  static const blueBg  = Color(0xFFEFF6FF);
  static const blueTxt = Color(0xFF1D4ED8);
  static const blueBdr = Color(0xFFBFDBFE);
  // violet (action chips)
  static const violetBg  = Color(0xFFEDE9FE);
  static const violetTxt = Color(0xFF5B21B6);
  static const violetBdr = Color(0xFFC4B5FD);
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
      return const _StatusStyle(bg: _S.greenBg, txt: _S.greenTxt, bdr: _S.greenBdr, label: 'Active');
    case 'inactive':
      return const _StatusStyle(bg: _S.redBg, txt: _S.redTxt, bdr: _S.redBdr, label: 'Inactive');
    case 'paused':
      return const _StatusStyle(bg: _S.amberBg, txt: _S.amberTxt, bdr: _S.amberBdr, label: 'Paused');
    case 'expired':
      return const _StatusStyle(bg: _S.redBg, txt: _S.redTxt, bdr: _S.redBdr, label: 'Expired');
    case 'cancelled':
      return const _StatusStyle(bg: _S.grayBg, txt: _S.grayTxt, bdr: _S.grayBdr, label: 'Cancelled');
    case 'out_for_delivery':
      return const _StatusStyle(bg: _S.blueBg, txt: _S.blueTxt, bdr: _S.blueBdr, label: 'Out for delivery');
    default:
      return const _StatusStyle(bg: _S.grayBg, txt: _S.grayTxt, bdr: _S.grayBdr, label: 'Unknown');
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
    Color(0xFF0D9488),
    Color(0xFF0891B2),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
  ];
  if (name.isEmpty) return colors[0];
  return colors[name.codeUnitAt(0) % colors.length];
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
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
      final Map<String, dynamic> res = await SubscriptionApi.list(customerId: widget.customer.id);
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
            (data['walletBalance'] as num?)?.toDouble() ?? c.effectiveWalletBalance,
          );
      final phone = (c.whatsapp?.isNotEmpty == true) ? c.whatsapp! : c.phone;
      if (phone.isEmpty) { AppSnackbar.error(context, 'No phone number'); return; }
      final ok = await WhatsAppHelper.openWithMessage(phone, msg);
      if (!mounted) return;
      if (ok) {
        AppSnackbar.success(context, 'Reminder sent (notification + WhatsApp)');
      } else {
        AppSnackbar.success(context, 'In-app reminder sent. Open WhatsApp manually if needed.');
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
    final hasPin = initial != null && (initial.lat != 0 || initial.lng != 0);
    final result = await showCustomerLocationPickSheet(
      context,
      initialPosition: hasPin ? LatLng(initial.lat, initial.lng) : null,
      initialAddress: c.address,
    );
    if (result == null || !mounted) return;
    setState(() => _savingCustomerLocation = true);
    try {
      await CustomerApi.update(
        c.id,
        buildCustomerLocationUpdateBody(lat: result.lat, lng: result.lng, address: result.address),
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
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Customer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        content: Text(
          'Delete ${_customer?.name ?? widget.customer.name}? This cannot be undone.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
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
                color: _S.redBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _S.redBdr, width: 0.5),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: _S.redTxt, fontWeight: FontWeight.w700, fontSize: 13),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card / surface colours that adapt
    final cardColor    = isDark ? const Color(0xFF1B1F2E) : Colors.white;
    final cardBorder   = isDark ? const Color(0xFF2F3347) : const Color(0xFFE2E8F0);
    final scaffoldBg   = isDark ? const Color(0xFF0E1020) : const Color(0xFFF0EBFF);
    final labelColor   = isDark ? cs.primary.withOpacity(0.9) : const Color(0xFF5B21B6);
    final textPrimary  = isDark ? cs.onSurface : const Color(0xFF0F172A);
    final textSecondary = isDark ? cs.onSurfaceVariant : const Color(0xFF64748B);

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
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          // AppBarTheme handles colours
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(c.name),
        ),
        body: Center(child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2)),
      );
    }

    final isLowBalance = c.effectiveWalletBalance < 100;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──
          SliverAppBar(
            pinned: true,
            // AppBarTheme sets bg/fg — no overrides needed
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text('Customer Detail'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () async {
                  await context.push(AppRoutes.editCustomer, extra: c);
                  _load();
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
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
                  color: cardColor,
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
                            color: _avatarColor(c.name).withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(c.name),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
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
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.2),
                            ),
                            const SizedBox(height: 3),
                            Text(c.phone, style: TextStyle(fontSize: 13, color: textSecondary)),
                            if (c.area?.isNotEmpty == true) ...[
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: cs.primary.withOpacity(0.25), width: 0.5),
                                ),
                                child: Text(
                                  c.area!,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _badge(_statusStyle(c.status)),
                    ],
                  ),
                ),

                // ── Wallet card (gradient — intentionally brand-coloured) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B3FE4), Color(0xFFA855F7)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.75)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${c.effectiveWalletBalance.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
                                  ),
                                  if (isLowBalance) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text('Low balance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _showCreditWalletSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                                ),
                                child: const Text('+ Add Money', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.22), width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Text('Subscription remaining', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Text('₹${subscriptionBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                _sectionLabel('Tiffin boxes to collect', labelColor),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomerTiffinNavRow(
                        key: ValueKey<String>('tiffin-row-${c.id}-$_tiffinRowGeneration'),
                        customerId: c.id,
                        customerName: c.name,
                        margin: EdgeInsets.zero,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push<void>(MaterialPageRoute<void>(
                              builder: (_) => TiffinCollectionHistoryScreen(customerId: c.id, customerName: c.name),
                            ));
                          },
                          icon: const Icon(Icons.calendar_month_rounded, size: 18),
                          label: const Text('History & calendar'),
                          // TextButtonTheme in app_theme.dart sets foregroundColor to primary
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Contact info ──
                _sectionLabel('Contact info', labelColor),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Phone', c.phone, textPrimary, textSecondary, cardBorder),
                      if (c.whatsapp?.isNotEmpty == true)
                        _infoRow('WhatsApp', c.whatsapp!, textPrimary, textSecondary, cardBorder),
                      if (c.email?.isNotEmpty == true)
                        _infoRow('Email', c.email!, textPrimary, textSecondary, cardBorder),
                      if (c.address?.isNotEmpty == true)
                        _infoRow('Address', c.address!, textPrimary, textSecondary, cardBorder),
                      if (c.landmark?.isNotEmpty == true)
                        _infoRow('Landmark', c.landmark!, textPrimary, textSecondary, cardBorder),
                      if (c.area?.isNotEmpty == true)
                        _infoRow('Area', c.area!, textPrimary, textSecondary, cardBorder),
                      if (c.notes?.isNotEmpty == true)
                        _infoRow('Notes', c.notes!, textPrimary, textSecondary, cardBorder, isLast: true),
                      if (c.tags?.isNotEmpty == true)
                        _infoRow('Tags', c.tags!.join(', '), textPrimary, textSecondary, cardBorder, isLast: true),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Location / zone ──
                _sectionLabel('Location / zone', labelColor),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_savingCustomerLocation)
                        LinearProgressIndicator(minHeight: 2, color: cs.primary),
                      _infoRow(
                        'Delivery zone',
                        c.zoneName?.trim().isNotEmpty == true ? c.zoneName!.trim() : '—',
                        textPrimary, textSecondary, cardBorder,
                      ),
                      if (!_hasCustomerMapLocation(c))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Zone Not Set',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: _isLoading ? null : () => _openCustomerLocationPicker(c),
                                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                                label: const Text('Set location'),
                                // FilledButtonTheme handles colour
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
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    tooltip: 'Open in Google Maps',
                                    onPressed: () => LocationHelper.openGoogleMaps(c.location!.lat, c.location!.lng),
                                    icon: Icon(Icons.location_pin, color: cs.primary, size: 26),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.address?.trim().isNotEmpty == true ? c.address!.trim() : 'Pinned location',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${c.location!.lat.toStringAsFixed(6)}, ${c.location!.lng.toStringAsFixed(6)}',
                                          style: TextStyle(fontSize: 11, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                children: [
                                  TextButton.icon(
                                    onPressed: _isLoading ? null : () => _openCustomerLocationPicker(c),
                                    icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                                    label: const Text('Edit location'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => LocationHelper.openGoogleMaps(c.location!.lat, c.location!.lng),
                                    icon: const Icon(Icons.map_outlined, size: 18),
                                    label: const Text('Google Maps'),
                                    style: TextButton.styleFrom(foregroundColor: textSecondary),
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

                if (activeSubscription != null && activeSubscription.payLater == true) ...[
                  _sectionLabel('Plan credit', labelColor),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _infoRow('Credit limit', '₹${(activeSubscription.creditLimit ?? activeSubscription.totalAmount ?? 0).toStringAsFixed(0)}', textPrimary, textSecondary, cardBorder),
                        if (activeSubscription.consumptionExposure != null)
                          _infoRow('Meal exposure', '₹${activeSubscription.consumptionExposure!.toStringAsFixed(0)}', textPrimary, textSecondary, cardBorder),
                        if (activeSubscription.creditHeadroom != null)
                          _infoRow('Credit headroom', '₹${activeSubscription.creditHeadroom!.toStringAsFixed(0)}', textPrimary, textSecondary, cardBorder),
                        _infoRow('Due on plan', '₹${activeSubscription.amountDueOnPlan.toStringAsFixed(0)}', textPrimary, textSecondary, cardBorder),
                        _infoRow(
                          'Pay by',
                          activeSubscription.paymentDueDate != null
                              ? DateFormat.yMMMd().format(activeSubscription.paymentDueDate!)
                              : '—',
                          textPrimary, textSecondary, cardBorder,
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
                      Row(
                        children: [
                          Expanded(
                            child: _actionBtn(
                              icon: Icons.phone_rounded, label: 'Call',
                              fg: _S.redTxt, bg: _S.redBg, bdr: _S.redBdr,
                              onTap: () async {
                                final ok = await WhatsAppHelper.callPhone(c.phone);
                                if (!mounted) return;
                                if (!ok) AppSnackbar.error(context, 'Could not open phone dialer');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionBtn(
                              icon: Icons.chat_rounded, label: 'WhatsApp',
                              fg: _S.greenTxt, bg: _S.greenBg, bdr: _S.greenBdr,
                              onTap: () => WhatsAppHelper.openChat(c.whatsapp ?? c.phone),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionBtn(
                              icon: Icons.account_balance_wallet_outlined, label: 'Wallet',
                              fg: _S.violetTxt, bg: _S.violetBg, bdr: _S.violetBdr,
                              onTap: _showCreditWalletSheet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          // OutlinedButtonTheme handles colour
                          onPressed: _openDailyReceipt,
                          icon: const Icon(Icons.receipt_outlined, size: 18),
                          label: const Text('Daily Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _actionBtn(
                        icon: Icons.notifications_outlined,
                        label: _sendingWalletReminder ? 'Sending reminder…' : 'Send wallet reminder',
                        fg: _S.amberTxt, bg: _S.amberBg, bdr: _S.amberBdr,
                        onTap: _sendingWalletReminder ? () {} : _sendWalletReminder,
                        fullWidth: true,
                      ),
                      const SizedBox(height: 10),
                      _actionBtn(
                        icon: Icons.delete_outline_rounded, label: 'Delete Customer',
                        fg: _S.redTxt, bg: _S.redBg, bdr: _S.redBdr,
                        onTap: _confirmDelete,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Subscription history ──
                _sectionLabel('Subscription history', labelColor),

                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2)),
                  )
                else if (_subscriptions.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                          child: Icon(Icons.assignment_outlined, color: cs.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text('No subscriptions yet', style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: _subscriptions.map((s) {
                        final st = _statusStyle(s.status);
                        final isDone = s.status.toLowerCase() == 'expired' || s.status.toLowerCase() == 'cancelled';
                        final totalDays = totalDaysInclusiveIST(s.startDate, s.endDate);
                        final remaining = remainingDaysInclusiveIST(s.startDate, s.endDate);
                        final progress = totalDays > 0 ? (1 - (remaining / totalDays)).clamp(0.0, 1.0) : 1.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder, width: 0.5),
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
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                                    ),
                                  ),
                                  _badge(st),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s.startDate.day}/${s.startDate.month}/${s.startDate.year} – ${s.endDate.day}/${s.endDate.month}/${s.endDate.year}',
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                              if (s.deliverySlot != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: cs.primary.withOpacity(0.25), width: 0.5),
                                  ),
                                  child: Text(
                                    s.deliverySlot!,
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
                                  ),
                                ),
                              ],
                              if (!isDone) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor: cs.primary.withOpacity(0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(st.bdr),
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

  Widget _sectionLabel(String text, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.7),
    ),
  );

  Widget _infoRow(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
    Color borderColor, {
    bool isLast = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      border: isLast ? null : Border(bottom: BorderSide(color: borderColor, width: 0.5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
          ),
        ),
      ],
    ),
  );

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
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
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
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
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
    _submitting = true;
    setState(() {});
    try {
      await CustomerApi.creditWallet(
        widget.customerId,
        amount: amount,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) widget.onSuccess();
    } catch (e) {
      if (mounted) widget.onError(e);
    } finally {
      _submitting = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg   = isDark ? const Color(0xFF1B1F2E) : Colors.white;
    final fieldBg   = isDark ? const Color(0xFF262A3A) : const Color(0xFFF8FAFC);
    final fieldBdr  = isDark ? const Color(0xFF2F3347) : const Color(0xFFE2E8F0);
    final textPrimary   = isDark ? cs.onSurface : const Color(0xFF0F172A);
    final textSecondary = isDark ? cs.onSurfaceVariant : const Color(0xFF64748B);

    InputDecoration inputDeco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(fontSize: 12, color: textSecondary),
      hintStyle: TextStyle(fontSize: 12, color: textSecondary.withOpacity(0.6)),
      filled: true,
      fillColor: fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: fieldBdr, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.primary, width: 1),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BottomSheetHandle(),
            Text(
              'Credit Wallet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.2),
            ),
            const SizedBox(height: 18),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w500),
              decoration: inputDeco('Amount (₹)', hint: '0'),
            ),
            const SizedBox(height: 14),

            Text(
              'PAYMENT METHOD',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.primary, letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: ['cash', 'razorpay'].map((m) {
                final sel = _paymentMethod == m;
                return GestureDetector(
                  onTap: () => setState(() => _paymentMethod = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? cs.primary : fieldBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? cs.primary : fieldBdr, width: 0.5),
                    ),
                    child: Text(
                      m == 'razorpay' ? 'Razorpay' : 'Cash',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _notesController,
              maxLines: 2,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: inputDeco('Notes (optional)'),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _submitting ? null : _submitWallet,
              child: _submitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Money', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}