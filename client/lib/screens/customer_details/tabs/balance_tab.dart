import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../models/customer_detail_model.dart';
import '../../../services/customer_detail_service.dart';

import 'customer_info_tab.dart';

/// Backend `extra-charge` chargeType: [separate] = pending due; [wallet] = deduct from wallet.
const _kChargeSeparate = 'separate';
const _kChargeWallet = 'wallet';

class _P {
  static const g1 = Color(0xFF7B3FE4);
  static const s900 = Color(0xFF0F172A);
  static const s600 = Color(0xFF475569);
  static const s400 = Color(0xFF94A3B8);
  static const s200 = Color(0xFFE2E8F0);
  static const s100 = Color(0xFFF8FAFC);
  static const green = Color(0xFF22C55E);
  static const greenDark = Color(0xFF16A34A);
  static const red = Color(0xFFEF4444);
  static const redDark = Color(0xFFDC2626);
  static const orange = Color(0xFFF59E0B);

  // Input decoration shared across all text fields.
  // Pass isDark from the widget's build() — this helper has no BuildContext of its own.
  static InputDecoration inputDec(
    String label, {
    String? hint,
    bool isDark = false,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(fontSize: 13, color: isDark ? _D.s400 : _P.s400),
        hintStyle: TextStyle(fontSize: 13, color: isDark ? _D.s400 : _P.s400),
        filled: true,
        fillColor: isDark ? _D.card : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? _D.s200 : _P.s200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _P.g1, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _P.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _P.red, width: 1.4),
        ),
      );

  // Solid purple button style
  static ButtonStyle get solidBtn => ElevatedButton.styleFrom(
        backgroundColor: _P.g1,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );

  // Solid red button style
  static ButtonStyle get redSolidBtn => ElevatedButton.styleFrom(
        backgroundColor: _P.red,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );

  // Outlined purple button style
  static ButtonStyle get purpleOutlineBtn => OutlinedButton.styleFrom(
        foregroundColor: _P.g1,
        side: const BorderSide(color: _P.g1, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );
}

// ─── Palette (dark mode — mirrors AppTheme.dark surfaces) ──────────────────
class _D {
  static const card = Color(0xFF1B1F2E);
  static const s900 = Color(0xFFF8FAFC);
  static const s600 = Color(0xFFCBD5E1);
  static const s400 = Color(0xFF94A3B8);
  static const s200 = Color(0xFF2F3347);
  static const greenBg = Color(0xFF0F2A1C);
  static const greenTxt = Color(0xFF4ADE80);
  static const redBg = Color(0xFF3A1212);
  static const redTxt = Color(0xFFFCA5A5);
}

/// Wallet / subscription balance and charge forms.
class BalanceTab extends StatefulWidget {
  const BalanceTab({super.key, required this.customerId});

  final String customerId;

  @override
  State<BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<BalanceTab>
    with AutomaticKeepAliveClientMixin {
  CustomerDetailBalance? _balance;
  bool _loading = true;
  String? _error;

  final _addAmount = TextEditingController();
  final _addNote = TextEditingController();
  String _payMode = 'cash';

  final _extraAmount = TextEditingController();
  final _extraReason = TextEditingController();

  final _addForm = GlobalKey<FormState>();
  final _extraForm = GlobalKey<FormState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addAmount.dispose();
    _addNote.dispose();
    _extraAmount.dispose();
    _extraReason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await CustomerDetailService.fetchBalance(widget.customerId);
      if (mounted) {
        setState(() {
          _balance = b;
          _loading = false;
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

  Future<void> _submitAdd() async {
    if (!(_addForm.currentState?.validate() ?? false)) return;
    final amt = double.tryParse(_addAmount.text.trim());
    if (amt == null || amt <= 0) {
      AppSnackbar.error(context, 'Enter a valid amount');
      return;
    }
    try {
      await CustomerDetailService.addBalance(
        widget.customerId,
        amount: amt,
        paymentMode: _payMode,
        note: _addNote.text.trim().isEmpty ? null : _addNote.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.success(context, 'Balance added');
      _addAmount.clear();
      _addNote.clear();
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e is ApiException ? (e.message ?? 'Error') : '$e');
    }
  }

  Future<void> _confirmExtra(String chargeType) async {
    if (!(_extraForm.currentState?.validate() ?? false)) return;
    final amt = double.tryParse(_extraAmount.text.trim());
    if (amt == null || amt <= 0) {
      AppSnackbar.error(context, 'Enter a valid amount');
      return;
    }
    final reason = _extraReason.text.trim();
    if (reason.isEmpty) {
      AppSnackbar.error(context, 'Reason is required');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogIsDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dialogIsDark ? _D.card : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: _P.orange, size: 22),
              const SizedBox(width: 8),
              Text(
                'Confirm charge',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: dialogIsDark ? _D.s900 : _P.s900,
                ),
              ),
            ],
          ),
          content: Text(
            chargeType == _kChargeSeparate
                ? '₹${amt.toStringAsFixed(0)} will be added to pending due.\n$reason'
                : '₹${amt.toStringAsFixed(0)} will be deducted from wallet balance.\n$reason',
            style: TextStyle(fontSize: 13, color: dialogIsDark ? _D.s600 : _P.s600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: dialogIsDark ? _D.s600 : _P.s600),
              ),
            ),
            ElevatedButton(
              style: _P.solidBtn,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    try {
      await CustomerDetailService.extraCharge(
        widget.customerId,
        amount: amt,
        note: reason,
        chargeType: chargeType,
      );
      if (!mounted) return;
      AppSnackbar.success(
        context,
        chargeType == _kChargeSeparate ? 'Pending due updated' : 'Deducted from wallet',
      );
      _extraAmount.clear();
      _extraReason.clear();
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e is ApiException ? (e.message ?? 'Error') : '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Shimmer.fromColors(
        baseColor: isDark ? _D.s200 : _P.s200,
        highlightColor: isDark ? _D.card : _P.s100,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? _D.card : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return CustomerDetailNetworkError(message: _error!, onRetry: _load);
    }

    final b = _balance!;
    final walletColor = b.walletBalance > 0
        ? (isDark ? _D.greenTxt : _P.greenDark)
        : (isDark ? _D.redTxt : _P.redDark);
    final subColor = b.subscriptionBalance > 0
        ? (isDark ? _D.greenTxt : _P.greenDark)
        : (isDark ? _D.redTxt : _P.redDark);
    final subDisplayAmount = b.subscriptionBalance.abs();
    final subDisplayText = b.subscriptionBalance < 0
        ? '₹${subDisplayAmount.toStringAsFixed(0)} due'
        : '₹${subDisplayAmount.toStringAsFixed(0)}';

    return RefreshIndicator(
      color: _P.g1,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [

          // ── Balance overview card ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? _D.card : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? _D.s200 : _P.s200, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? _D.s600 : _P.s600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _load,
                      child: const Icon(Icons.refresh_rounded, size: 20, color: _P.g1),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Wallet balance
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: b.walletBalance > 0
                            ? (isDark ? _D.greenBg : const Color(0xFFDCFCE7))
                            : (isDark ? _D.redBg : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          size: 18, color: walletColor),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wallet Balance',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? _D.s400 : _P.s400,
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(height: 1),
                        Text(
                          '₹${b.walletBalance.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: walletColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, thickness: 0.8, color: isDark ? _D.s200 : _P.s200),
                const SizedBox(height: 10),

                // Subscription balance
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: b.subscriptionBalance > 0
                            ? (isDark ? _D.greenBg : const Color(0xFFDCFCE7))
                            : (isDark ? _D.redBg : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.subscriptions_rounded,
                          size: 18, color: subColor),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subscription Balance',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? _D.s400 : _P.s400,
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(height: 1),
                        Text(
                          subDisplayText,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: subColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Add Balance section ───────────────────────────────────
          Row(
            children: [
              const Icon(Icons.add_circle_outline_rounded, color: _P.green, size: 18),
              const SizedBox(width: 6),
              Text('Add Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? _D.s900 : _P.s900,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Form(
            key: _addForm,
            child: Column(
              children: [
                TextFormField(
                  controller: _addAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: _P.inputDec('Amount', isDark: isDark),
                  style: TextStyle(fontSize: 14, color: isDark ? _D.s900 : _P.s900),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _payMode,
                  decoration: _P.inputDec('Payment mode', isDark: isDark),
                  dropdownColor: isDark ? _D.card : Colors.white,
                  style: TextStyle(fontSize: 14, color: isDark ? _D.s900 : _P.s900),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? _D.s400 : _P.s400),
                  items: [
                    DropdownMenuItem(
                      value: 'cash',
                      child: Row(children: [
                        Icon(Icons.money_rounded, size: 16, color: isDark ? _D.s600 : _P.s600),
                        const SizedBox(width: 8),
                        const Text('Cash'),
                      ]),
                    ),
                    DropdownMenuItem(
                      value: 'upi',
                      child: Row(children: [
                        Icon(Icons.phone_android_rounded, size: 16, color: isDark ? _D.s600 : _P.s600),
                        const SizedBox(width: 8),
                        const Text('UPI'),
                      ]),
                    ),
                    DropdownMenuItem(
                      value: 'online',
                      child: Row(children: [
                        Icon(Icons.credit_card_rounded, size: 16, color: isDark ? _D.s600 : _P.s600),
                        const SizedBox(width: 8),
                        const Text('Online'),
                      ]),
                    ),
                  ],
                  onChanged: (v) => setState(() => _payMode = v ?? 'cash'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addNote,
                  decoration: _P.inputDec('Note (optional)', isDark: isDark),
                  style: TextStyle(fontSize: 14, color: isDark ? _D.s900 : _P.s900),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: _P.solidBtn,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Add Balance'),
                    onPressed: _submitAdd,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Extra Charge section ──────────────────────────────────
          Row(
            children: [
              const Icon(Icons.remove_circle_outline_rounded, color: _P.red, size: 18),
              const SizedBox(width: 6),
              Text('Extra charge',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? _D.s900 : _P.s900,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bill an extra item: either add to pending due, or take payment from wallet.',
            style: TextStyle(fontSize: 12, color: isDark ? _D.s400 : _P.s400, height: 1.35),
          ),
          const SizedBox(height: 10),
          Form(
            key: _extraForm,
            child: Column(
              children: [
                TextFormField(
                  controller: _extraAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: _P.inputDec('Amount', isDark: isDark),
                  style: TextStyle(fontSize: 14, color: isDark ? _D.s900 : _P.s900),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _extraReason,
                  decoration: _P.inputDec('Reason', hint: 'e.g. 2 extra rotis', isDark: isDark),
                  style: TextStyle(fontSize: 14, color: isDark ? _D.s900 : _P.s900),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          style: _P.purpleOutlineBtn,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                          label: const Text('Charge Separately', maxLines: 1, overflow: TextOverflow.ellipsis),
                          onPressed: () => _confirmExtra(_kChargeSeparate),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: _P.redSolidBtn,
                          icon: const Icon(Icons.remove_circle_rounded, size: 15),
                          label: const Text('From wallet'),
                          onPressed: () => _confirmExtra(_kChargeWallet),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}