import 'package:flutter/material.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../customers/data/customer_api.dart';
import '../../../payments/data/invoice_api.dart';
import '../../../payments/data/payment_api.dart';
import '../../../payments/models/invoice_model.dart';
import '../../../payments/models/payment_model.dart';
import '../../../../models/customer_model.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    this.embeddedInShell = false,
    this.embeddedInFinanceShell = false,
  });
  final bool embeddedInShell;
  /// When true with [embeddedInShell], hides the top violet header row (used inside [FinanceShell]).
  final bool embeddedInFinanceShell;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentModel> _payments = [];
  List<InvoiceModel> _overdue = [];
  List<CustomerModel> _customers = [];
  bool _loading = true;
  final _amountController = TextEditingController();
  CustomerModel? _selectedCustomer;
  String _mode = 'cash';
  bool _saving = false;

  // Payment history pagination (server: GET /payments?page&limit)
  static const int _historyPageSize = 20;
  int _paymentsPage = 1;
  int _paymentsTotal = 0;
  int _paymentsTotalPages = 1;
  bool _loadingMore = false;

  /// Sum of amounts for payments created today (separate query; not limited to current page).
  double _todayCollected = 0;

  // ── Palette ───────────────────────────────────────────────────────────────
  static const _violet900 = Color(0xFF2D1B69);
  static const _violet800 = Color(0xFF3D2490);
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet500 = Color(0xFF6C42F5);
  static const _violet200 = Color(0xFFCDBEFA);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);

  static const _bg = Color(0xFFF6F4FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _divider = Color(0xFFEEEBFA);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);

  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFCECEB);
  static const _success = Color(0xFF0F7B0F);
  static const _successSoft = Color(0xFFE6F4EA);

  // ── Helpers ───────────────────────────────────────────────────────────────
  double get _totalOverdue => _overdue.fold(0.0, (s, i) => s + (i.amount));

  String _fmt(double? v) {
    final val = v ?? 0;
    return val >= 1000
        ? '₹${(val / 1000).toStringAsFixed(1)}k'
        : '₹${val.toStringAsFixed(0)}';
  }

  String _fmtDate(DateTime? d) => d != null
      ? '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
      : '—';

  IconData _methodIcon(String m) {
    switch (m) {
      case 'razorpay':
        return Icons.bolt_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payRes = await PaymentApi.list(limit: _historyPageSize);
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final todayRes = await PaymentApi.list(
        page: 1,
        limit: 100,
        fromDate: startOfDay.toIso8601String(),
        toDate: endOfDay.toIso8601String(),
      );
      final overdueList = await InvoiceApi.getOverdue();
      final custRes = await CustomerApi.list(limit: 100, status: 'active');
      final custData = custRes['data'];
      List<dynamic> rawList = [];
      if (custData is Map<String, dynamic>) {
        rawList = (custData['data'] as List?) ?? [];
      } else if (custData is List) {
        rawList = custData;
      }
      final customers = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => CustomerModel.fromJson(e))
          .toList();
      final todaySum = todayRes.items.fold<double>(0, (s, p) => s + p.amount);
      if (mounted) {
        setState(() {
          _payments = payRes.items;
          _paymentsPage = payRes.page;
          _paymentsTotal = payRes.total;
          _paymentsTotalPages = payRes.totalPages;
          _todayCollected = todaySum;
          _overdue = overdueList;
          _customers = customers;
        });
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePayments() async {
    if (_loadingMore || _paymentsPage >= _paymentsTotalPages) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _paymentsPage + 1;
      final res = await PaymentApi.list(
        page: nextPage,
        limit: _historyPageSize,
      );
      if (!mounted) return;
      setState(() {
        _payments = [..._payments, ...res.items];
        _paymentsPage = res.page;
        _paymentsTotal = res.total;
        _paymentsTotalPages = res.totalPages;
      });
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _recordPayment() async {
    if (_selectedCustomer == null) {
      AppSnackbar.error(context, 'Please select a customer');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AppSnackbar.error(context, 'Enter a valid amount');
      return;
    }
    setState(() => _saving = true);
    try {
      await PaymentApi.create({
        'customerId': _selectedCustomer!.id,
        'amount': amount,
        'paymentMethod': _mode,
      });
      if (mounted) {
        AppSnackbar.success(context, 'Payment recorded successfully');
        _amountController.clear();
        setState(() => _selectedCustomer = null);
        _load();
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Root build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? _skeleton()
        : RefreshIndicator(
            color: _violet600,
            strokeWidth: 2,
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                MediaQuery.of(context).padding.bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryRow(),
                  const SizedBox(height: 20),
                  _collectCard(),
                  const SizedBox(height: 24),
                  _sectionLabel('Overdue Invoices', _overdue.length),
                  const SizedBox(height: 10),
                  _overdueSection(),
                  const SizedBox(height: 24),
                  _sectionLabel('Payment History', _paymentsTotal),
                  const SizedBox(height: 10),
                  _historySection(),
                ],
              ),
            ),
          );

    if (widget.embeddedInShell) {
      return ColoredBox(
        color: _bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embeddedInFinanceShell) _shellHeader(),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _violet700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Finance & Payments',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        elevation: 0,
      ),
      body: body,
    );
  }

  // ── Shell header ──────────────────────────────────────────────────────────
  Widget _shellHeader() => Container(
    color: _violet700,
    padding: const EdgeInsets.fromLTRB(4, 8, 20, 12),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const Text(
          'Finance & Payments',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.1,
          ),
        ),
      ],
    ),
  );

  // ── Summary strip ─────────────────────────────────────────────────────────
  Widget _summaryRow() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      children: [
        Expanded(
          child: _StatTile(
            label: "Today's Collection",
            value: _fmt(_todayCollected),
            icon: Icons.trending_up_rounded,
            iconBg: _successSoft,
            iconColor: _success,
            valueColor: _success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Total Overdue',
            value: _fmt(_totalOverdue),
            icon: Icons.warning_amber_rounded,
            iconBg: _dangerSoft,
            iconColor: _danger,
            valueColor: _danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Payments',
            value: '$_paymentsTotal',
            icon: Icons.receipt_long_rounded,
            iconBg: _violet100,
            iconColor: _violet600,
            valueColor: _violet700,
          ),
        ),
      ],
    ),
  );

  // ── Collect Payment card ──────────────────────────────────────────────────
  Widget _collectCard() => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: _violet900.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Gradient header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_violet800, _violet600],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_card_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text(
                'Collect Payment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel('Customer'),
              const SizedBox(height: 6),
              _customerDropdown(),
              const SizedBox(height: 14),
              _fieldLabel('Amount (₹)'),
              const SizedBox(height: 6),
              _amountField(),
              const SizedBox(height: 14),
              _fieldLabel('Payment Method'),
              const SizedBox(height: 8),
              _methodChips(),
              const SizedBox(height: 20),
              _submitButton(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _textSecondary,
      letterSpacing: 0.2,
    ),
  );

  Widget _customerDropdown() => Container(
    decoration: BoxDecoration(
      color: _violet50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<CustomerModel>(
        value: _selectedCustomer,
        hint: Text(
          'Select customer',
          style: TextStyle(
            color: _textSecondary.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        isExpanded: true,
        dropdownColor: _surface,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _textSecondary,
        ),
        items: _customers
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(
                  '${c.name}  ·  ${c.phone}',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _selectedCustomer = v),
      ),
    ),
  );

  Widget _amountField() => TextField(
    controller: _amountController,
    keyboardType: TextInputType.number,
    style: const TextStyle(
      color: _textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    decoration: InputDecoration(
      hintText: '0',
      hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
      prefixIcon: const Padding(
        padding: EdgeInsets.only(left: 14, right: 8),
        child: Text(
          '₹',
          style: TextStyle(
            color: _textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: _violet50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _violet500, width: 1.5),
      ),
    ),
  );

  Widget _methodChips() {
    const methods = [
      ('cash', Icons.payments_rounded, 'Cash'),
      ('razorpay', Icons.bolt_rounded, 'Razorpay'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: methods.map((m) {
        final sel = _mode == m.$1;
        return GestureDetector(
          onTap: () => setState(() => _mode = m.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? _violet600 : _violet50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel ? _violet500 : _border,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  m.$2,
                  size: 14,
                  color: sel ? Colors.white : _textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  m.$3,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _submitButton() => SizedBox(
    height: 50,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_violet700, _violet500],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: _violet600.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saving ? null : _recordPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: _violet200,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Record Payment',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String title, int count) => Row(
    children: [
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _violet100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _violet700,
          ),
        ),
      ),
    ],
  );

  // ── Overdue section ───────────────────────────────────────────────────────
  Widget _overdueSection() {
    if (_overdue.isEmpty) {
      return _EmptyState(
        icon: Icons.check_circle_outline_rounded,
        iconColor: _success,
        iconBg: _successSoft,
        message: 'No overdue payments',
        sub: 'All invoices are up to date',
      );
    }
    return Column(
      children: _overdue
          .map((inv) => _OverdueTile(inv: inv, fmtDate: _fmtDate, fmtAmt: _fmt))
          .toList(),
    );
  }

  // ── History section ───────────────────────────────────────────────────────
  Widget _historySection() {
    if (_payments.isEmpty) {
      return _EmptyState(
        icon: Icons.receipt_long_rounded,
        iconColor: _violet600,
        iconBg: _violet100,
        message: 'No payments recorded',
        sub: 'Payments will appear here',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._payments.map(
          (p) => _PaymentTile(
            payment: p,
            fmtDate: _fmtDate,
            fmtAmt: _fmt,
            methodIcon: _methodIcon,
          ),
        ),
        if (_paymentsPage < _paymentsTotalPages) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _loadingMore ? null : _loadMorePayments,
            style: OutlinedButton.styleFrom(
              foregroundColor: _violet700,
              side: const BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _loadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(
              _loadingMore
                  ? 'Loading…'
                  : 'Load more (${_payments.length} / $_paymentsTotal)',
            ),
          ),
        ],
      ],
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────
  Widget _skeleton() => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      16,
      20,
      16,
      MediaQuery.of(context).padding.bottom + 32,
    ),
    child: Column(
      children: List.generate(
        6,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: i == 0 ? 60 : 72,
          decoration: BoxDecoration(
            color: _divider,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.valueColor,
  });
  final String label, value;
  final IconData icon;
  final Color iconBg, iconColor, valueColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE4DFF7)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2D1B69).withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7B6DAB),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _OverdueTile extends StatelessWidget {
  const _OverdueTile({
    required this.inv,
    required this.fmtDate,
    required this.fmtAmt,
  });
  final InvoiceModel inv;
  final String Function(DateTime?) fmtDate;
  final String Function(double) fmtAmt;

  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFCECEB);
  static const _border = Color(0xFFE4DFF7);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _dangerSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: _danger,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inv.customerName ?? inv.customerId,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Due: ${fmtDate(inv.dueDate)}',
                style: const TextStyle(fontSize: 12, color: _textSecondary),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fmtAmt(inv.amount),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _danger,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _dangerSoft,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'OVERDUE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _danger,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.fmtDate,
    required this.fmtAmt,
    required this.methodIcon,
  });
  final PaymentModel payment;
  final String Function(DateTime?) fmtDate;
  final String Function(double) fmtAmt;
  final IconData Function(String) methodIcon;

  static const _border = Color(0xFFE4DFF7);
  static const _iconBg = Color(0xFFEDE8FD);
  static const _iconColor = Color(0xFF5B35D5);
  static const _labelBg = Color(0xFFF5F2FF);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);
  static const _success = Color(0xFF0F7B0F);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            methodIcon(payment.paymentMethod),
            color: _iconColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.customerName ?? payment.customerId,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _labelBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      payment.paymentMethod.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    fmtDate(payment.paymentDate),
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          fmtAmt(payment.amount),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: _success,
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.message,
    required this.sub,
  });
  final IconData icon;
  final Color iconColor, iconBg;
  final String message, sub;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE4DFF7)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1A0E45),
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7B6DAB)),
            ),
          ],
        ),
      ],
    ),
  );
}
