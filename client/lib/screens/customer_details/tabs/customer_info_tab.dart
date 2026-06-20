import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../features/customers/presentation/screens/tiffin_collection_history_screen.dart';
import '../../../features/customers/presentation/widgets/customer_tiffin_nav_row.dart';
import '../../../features/payments/presentation/widgets/daily_receipt_sheet.dart';
import '../../../models/customer_detail_model.dart';
import '../../../services/customer_detail_service.dart';

// ─── Palette (light mode — unchanged) ──────────────────────────────────────
class _P {
  static const primary = Color(0xFF7B3FE4);
  static const primaryBg = Color(0xFFF5F3FF);
  static const primaryBdr = Color(0xFFEDE9FE);
  static const s900 = Color(0xFF0F172A);
  static const s600 = Color(0xFF475569);
  static const s400 = Color(0xFF94A3B8);
  static const s200 = Color(0xFFE2E8F0);
  static const s50 = Color(0xFFF8FAFC);
  static const greenBg = Color(0xFFF0FDF4);
  static const greenBdr = Color(0xFF86EFAC);
  static const greenTxt = Color(0xFF166534);
  static const green = Color(0xFF22C55E);
  static const waGreen = Color(0xFF25D366);
  static const redBg = Color(0xFFFEF2F2);
  static const red = Color(0xFFDC2626);
  static const amberBg = Color(0xFFFFF7ED);
  static const amber = Color(0xFFD97706);
  static const pageBg = Color(0xFFF8F7FF);
}

// ─── Palette (dark mode — mirrors AppTheme.dark surfaces) ──────────────────
class _D {
  static const card = Color(0xFF1B1F2E);
  static const cardBdr = Color(0xFF2F3347);
  static const primaryBg = Color(0xFF241B42);
  static const primaryBdr = Color(0xFF3A2E66);
  static const s900 = Color(0xFFF8FAFC);
  static const s600 = Color(0xFFCBD5E1);
  static const s400 = Color(0xFF94A3B8);
  static const s200 = Color(0xFF2F3347);
  static const greenBg = Color(0xFF0F2A1C);
  static const greenBdr = Color(0xFF1F6B3F);
  static const greenTxt = Color(0xFF4ADE80);
  static const redBg = Color(0xFF3A1212);
  static const redBdr = Color(0xFF7A2E2E);
  static const redTxt = Color(0xFFFCA5A5);
  static const amberBg = Color(0xFF3A2A0F);
}

// ─── Helpers ─────────────────────────────────────────────────────────────
Color _avatarColor(String name) {
  const colors = [
    Color(0xFF7B3FE4),
    Color(0xFF0891B2),
    Color(0xFF0D9488),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
  ];
  if (name.isEmpty) return colors[0];
  return colors[name.codeUnitAt(0) % colors.length];
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ─── Main Widget ────────────────────────────────────────────────────────────
class CustomerInfoTab extends StatefulWidget {
  const CustomerInfoTab({super.key, required this.customerId});
  final String customerId;

  @override
  State<CustomerInfoTab> createState() => _CustomerInfoTabState();
}

class _CustomerInfoTabState extends State<CustomerInfoTab>
    with AutomaticKeepAliveClientMixin {
  CustomerDetailInfo? _info;
  bool _loading = true;
  String? _error;
  bool _sendingLink = false;
  bool _sendingWalletReminder = false;
  bool _savingCreditLimit = false;
  int _tiffinRowGeneration = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await CustomerDetailService.fetchInfo(widget.customerId);
      if (mounted) {
        setState(() {
          _info = data;
          _loading = false;
          _tiffinRowGeneration++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ApiException ? (e.message ?? 'Error') : '$e';
        });
      }
    }
  }

  Future<void> _sendLoginLink() async {
    setState(() => _sendingLink = true);
    try {
      final result = await CustomerDetailService.sendLoginLink(
        widget.customerId,
      );
      if (!mounted) return;
      final phone = result['phone']?.toString() ?? '';
      final message = result['message']?.toString() ?? '';
      final ok = await WhatsAppHelper.openWithMessage(phone, message);
      if (!mounted) return;
      ok
          ? AppSnackbar.success(context, 'Login link sent to $phone')
          : AppSnackbar.error(context, 'Could not open WhatsApp');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _sendingLink = false);
    }
  }

  Future<void> _onCallTap(String phone) async {
    final ok = await WhatsAppHelper.callPhone(phone);
    if (!mounted) return;
    if (!ok) {
      AppSnackbar.error(context, 'Could not open phone dialer');
    }
  }

  Future<void> _sendWalletReminder(CustomerDetailInfo info) async {
    setState(() => _sendingWalletReminder = true);
    try {
      final data = await CustomerDetailService.notifyWalletReminder(
        widget.customerId,
      );
      if (!mounted) return;
      final msg =
          data['whatsappMessage']?.toString() ??
          WhatsAppHelper.lowBalanceMessage(
            info.name,
            (data['walletBalance'] as num?)?.toDouble() ?? 0,
          );
      final ok = await WhatsAppHelper.openWithMessage(info.phone, msg);
      if (!mounted) return;
      if (ok) {
        AppSnackbar.success(
          context,
          'Reminder sent (notification + WhatsApp)',
        );
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

  Future<void> _openDailyReceipt() async {
    final info = _info;
    if (info == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DailyReceiptSheet(
        key: ValueKey(
          'daily-receipt-${widget.customerId}-${picked.toIso8601String()}',
        ),
        customerId: widget.customerId,
        customerName: info.name,
        initialDate: picked,
      ),
    );
  }

  String _money(double? value, {String empty = 'Not set'}) {
    if (value == null) return empty;
    return '₹${value.toStringAsFixed(0)}';
  }

  Future<void> _openCreditLimitEditor(CustomerDetailInfo info) async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreditLimitEditorSheet(
        initialValue: info.creditLimit,
        hasCreditLimit: info.hasCreditLimit,
      ),
    );
    if (amount == null || !mounted) return;

    setState(() => _savingCreditLimit = true);
    try {
      final updated = await CustomerDetailService.updateCreditLimit(
        widget.customerId,
        creditLimit: amount,
      );
      if (!mounted) return;
      setState(() => _info = updated);
      AppSnackbar.success(context, 'Credit limit updated');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _savingCreditLimit = false);
    }
  }

  String _deliveryZoneLabel(CustomerDetailInfo i) {
    if (i.zoneName?.trim().isNotEmpty == true) return i.zoneName!.trim();
    if (i.zone?.trim().isNotEmpty == true) return i.zone!.trim();
    return '—';
  }

  // ── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return _buildShimmer();
    if (_error != null) {
      return CustomerDetailNetworkError(message: _error!, onRetry: _load);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final i = _info!;
    final active = i.status.toLowerCase() == 'active';
    final color = _avatarColor(i.name);

    return RefreshIndicator(
      color: _P.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          // ── Profile card ──────────────────────────────────────────────
          _Card(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(i.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? _D.s900 : _P.s900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        i.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? _D.s400 : _P.s400,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? (isDark ? _D.greenBg : _P.greenBg)
                              : (isDark ? _D.redBg : _P.redBg),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? (isDark ? _D.greenBdr : _P.greenBdr)
                                : (isDark
                                      ? _D.redBdr
                                      : const Color(0xFFFCA5A5)),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: active ? _P.green : _P.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              active ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? (isDark ? _D.greenTxt : _P.greenTxt)
                                    : (isDark
                                          ? _D.redTxt
                                          : const Color(0xFF991B1B)),
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
          ),

          const SizedBox(height: 16),

          // ── Contact section ─────────────────────────────────────────────
          _SectionLabel('Contact details'),
          const SizedBox(height: 6),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Full name',
                  value: i.name,
                ),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: i.phone,
                ),
                _InfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: i.email.isEmpty ? 'Not provided' : i.email,
                  muted: i.email.isEmpty,
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: i.address.isEmpty ? 'Not provided' : i.address,
                  muted: i.address.isEmpty,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Zone ─────────────────────────────────────────────────────────
          _SectionLabel('Delivery zone'),
          const SizedBox(height: 6),
          _Card(
            padding: EdgeInsets.zero,
            child: _InfoRow(
              icon: Icons.route_outlined,
              label: 'Zone',
              value: _deliveryZoneLabel(i),
              muted: _deliveryZoneLabel(i) == '—',
              isLast: true,
            ),
          ),

          const SizedBox(height: 16),

          // ── Subscription section ────────────────────────────────────────
          _SectionLabel('Subscription'),
          const SizedBox(height: 6),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Plan name',
                  value: i.planName.isEmpty ? '—' : i.planName,
                ),
                _InfoRow(
                  icon: Icons.account_balance_outlined,
                  label: 'Remaining subscription balance',
                  value: _money(i.subscriptionBalance, empty: '₹0'),
                ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Start date',
                  value: i.startDate.isEmpty ? '—' : _fmt(i.startDate),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Credit limit ─────────────────────────────────────────────────
          _SectionLabel('Credit limit'),
          const SizedBox(height: 6),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_savingCreditLimit)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: _P.primary,
                  ),
                _InfoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Credit limit',
                  value: _money(i.creditLimit),
                  muted: !i.hasCreditLimit,
                ),
                if (i.payLater && i.consumptionExposure != null)
                  _InfoRow(
                    icon: Icons.restaurant_menu_outlined,
                    label: 'Meal amount used',
                    value: _money(i.consumptionExposure, empty: '₹0'),
                  ),
                if (i.payLater && i.creditHeadroom != null)
                  _InfoRow(
                    icon: Icons.savings_outlined,
                    label: 'Remaining credit',
                    value: _money(i.creditHeadroom, empty: '₹0'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: FilledButton.icon(
                    onPressed: _savingCreditLimit
                        ? null
                        : () => _openCreditLimitEditor(i),
                    icon: Icon(
                      i.hasCreditLimit
                          ? Icons.edit_outlined
                          : Icons.add_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      i.hasCreditLimit
                          ? 'Edit credit limit'
                          : 'Add credit limit',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _P.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Tiffin boxes to collect ──────────────────────────────────────
          _SectionLabel('Tiffin boxes to collect'),
          const SizedBox(height: 6),
          CustomerTiffinNavRow(
            key: ValueKey<String>(
              'tiffin-row-${widget.customerId}-$_tiffinRowGeneration',
            ),
            customerId: widget.customerId,
            customerName: i.name,
            margin: EdgeInsets.zero,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TiffinCollectionHistoryScreen(
                      customerId: widget.customerId,
                      customerName: i.name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: const Text('History & calendar'),
              style: TextButton.styleFrom(
                foregroundColor: _P.primary,
                padding: const EdgeInsets.only(top: 2, bottom: 0),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Quick actions ──────────────────────────────────────────────
          _SectionLabel('Quick actions'),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.0,
            children: [
              _ActionTile(
                icon: Icons.phone_rounded,
                label: 'Call',
                sub: 'Open dialer',
                iconBg: isDark ? _D.redBg : _P.redBg,
                iconColor: _P.red,
                onTap: () => _onCallTap(i.phone),
              ),
              _ActionTile(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                sub: 'Send message',
                iconBg: isDark ? _D.greenBg : const Color(0xFFF0FDF4),
                iconColor: _P.waGreen,
                onTap: () => WhatsAppHelper.openChat(i.phone),
              ),
              _ActionTile(
                icon: Icons.receipt_outlined,
                label: 'Daily receipt',
                sub: 'Download PDF',
                iconBg: isDark ? _D.primaryBg : _P.primaryBg,
                iconColor: _P.primary,
                onTap: _openDailyReceipt,
              ),
              _ActionTile(
                icon: Icons.notifications_outlined,
                label: 'Low balance',
                sub: _sendingWalletReminder ? 'Sending…' : 'Send reminder',
                iconBg: isDark ? _D.amberBg : _P.amberBg,
                iconColor: _P.amber,
                onTap: _sendingWalletReminder
                    ? () {}
                    : () => _sendWalletReminder(i),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Customer portal ───────────────────────────────────────────────
          _SectionLabel('Customer portal'),
          const SizedBox(height: 6),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isDark ? _D.primaryBg : _P.primaryBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.link_rounded,
                          color: _P.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send login link',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? _D.s900 : _P.s900,
                            ),
                          ),
                          Text(
                            'Via WhatsApp · Valid 24h',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? _D.s400 : _P.s400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: (isDark ? _D.s200 : _P.s200).withValues(alpha: 0.5),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer gets a one-tap secure link to view their plan, deliveries and invoices.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? _D.s600 : _P.s600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sendingLink ? null : _sendLoginLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _P.waGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _P.waGreen.withValues(
                              alpha: 0.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          icon: _sendingLink
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.chat_rounded, size: 16),
                          label: Text(
                            _sendingLink ? 'Sending...' : 'Send via WhatsApp',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat.yMMMd().format(d.toLocal());
  }

  Widget _buildShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? _D.s200 : _P.s200,
      highlightColor: isDark ? _D.card : _P.s50,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: 5,
        itemBuilder: (context, _) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? _D.card : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditLimitEditorSheet extends StatefulWidget {
  const _CreditLimitEditorSheet({
    required this.initialValue,
    required this.hasCreditLimit,
  });

  final double? initialValue;
  final bool hasCreditLimit;

  @override
  State<_CreditLimitEditorSheet> createState() =>
      _CreditLimitEditorSheetState();
}

class _CreditLimitEditorSheetState extends State<_CreditLimitEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, double.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kb = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + kb),
        decoration: BoxDecoration(
          color: isDark ? _D.card : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? _D.s200 : _P.s200),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.hasCreditLimit
                    ? 'Edit credit limit'
                    : 'Add credit limit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? _D.s900 : _P.s900,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Credit limit (₹)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  final parsed = double.tryParse(raw);
                  if (raw.isEmpty) return 'Required';
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _P.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable sub-widgets ───────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _D.card : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? _D.cardBdr : _P.primaryBdr,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: _P.primary,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool muted;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDark ? _D.primaryBg : _P.primaryBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _P.primary, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? _D.s400 : _P.s400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: muted
                            ? (isDark ? _D.s400 : _P.s400)
                            : (isDark ? _D.s900 : _P.s900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 54,
            color: (isDark ? _D.s200 : _P.s200).withValues(alpha: 0.6),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sub;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? _D.card : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? _D.cardBdr : _P.primaryBdr,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? _D.s900 : _P.s900,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? _D.s400 : _P.s400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error widget ───────────────────────────────────────────────────────────
class CustomerDetailNetworkError extends StatelessWidget {
  const CustomerDetailNetworkError({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offline = message.toLowerCase().contains('internet');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GestureDetector(
          onTap: offline ? onRetry : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark ? _D.primaryBg : _P.primaryBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  offline
                      ? Icons.wifi_off_rounded
                      : Icons.error_outline_rounded,
                  size: 26,
                  color: _P.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                offline ? 'No internet connection' : 'Something went wrong',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? _D.s900 : _P.s900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                offline ? 'Tap to retry' : message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? _D.s400 : _P.s400,
                ),
              ),
              if (!offline) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _P.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}