import 'package:flutter/material.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../customers/data/customer_api.dart';
import '../../../payments/data/invoice_api.dart';
import '../../../payments/models/invoice_model.dart';
import '../../../../models/customer_model.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  // ── Violet palette ────────────────────────────────────────────────────────
  static const _violet900 = Color(0xFF2D1B69);
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet500 = Color(0xFF6C42F5);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _bg = Color(0xFFF6F4FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _divider = Color(0xFFEEEBFA);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);
  static const _success = Color(0xFF0F7B0F);
  static const _successSoft = Color(0xFFE6F4EA);
  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFCECEB);
  static const _warning = Color(0xFFBA7517);
  static const _warningSoft = Color(0xFFFAEEDA);

  // ── State ─────────────────────────────────────────────────────────────────
  List<InvoiceModel> _invoices = [];
  bool _loading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── API (unchanged) ───────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await InvoiceApi.list(
        limit: 50,
        paymentStatus: _statusFilter,
      );
      if (mounted) setState(() => _invoices = list);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDetail(InvoiceModel inv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InvoiceDetailSheet(
        inv: inv,
        onVoided: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  void _openGenerateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GenerateInvoiceSheet(
        onGenerated: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  // ── Status meta ───────────────────────────────────────────────────────────
  static (Color, Color, String) _statusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return (_success, _successSoft, 'PAID');
      case 'partial':
        return (_warning, _warningSoft, 'PARTIAL');
      case 'voided':
        return (_textSecondary, _divider, 'VOIDED');
      default:
        return (_warning, _warningSoft, 'UNPAID');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _violet700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Invoices',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          // Count badge
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_invoices.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Filter popup
          PopupMenuButton<String?>(
            icon: const Icon(
              Icons.filter_list_rounded,
              color: Colors.white,
              size: 22,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            initialValue: _statusFilter,
            onSelected: (v) => setState(() {
              _statusFilter = v;
              _load();
            }),
            itemBuilder: (_) => [
              _popupItem(null, 'All Invoices', Icons.list_alt_rounded),
              _popupItem('unpaid', 'Unpaid', Icons.pending_outlined),
              _popupItem('partial', 'Partial', Icons.timelapse_rounded),
              _popupItem('paid', 'Paid', Icons.check_circle_outline_rounded),
            ],
          ),
        ],
        // Active filter indicator
        bottom: _statusFilter != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Container(
                  color: _violet700,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _statusFilter![0].toUpperCase() +
                                  _statusFilter!.substring(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _violet700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() {
                                _statusFilter = null;
                                _load();
                              }),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: _violet700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGenerateSheet,
        backgroundColor: _violet600,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
        label: const Text(
          'Generate',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: _violet600,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: _violet600,
              onRefresh: _load,
              child: _invoices.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        MediaQuery.of(context).padding.bottom + 100,
                      ),
                      itemCount: _invoices.length,
                      itemBuilder: (ctx, i) => _buildInvoiceCard(_invoices[i]),
                    ),
            ),
    );
  }

  PopupMenuItem<String?> _popupItem(String? val, String label, IconData icon) =>
      PopupMenuItem(
        value: val,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _violet50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: _violet600),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
            if (val == _statusFilter) ...[
              const Spacer(),
              const Icon(Icons.check_rounded, size: 15, color: _violet600),
            ],
          ],
        ),
      );

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty() => ListView(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).padding.bottom + 24,
    ),
    children: [
      const SizedBox(height: 80),
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _violet100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: _violet600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No invoices found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap + Generate to create one',
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
      ),
    ],
  );

  // ── Invoice card ──────────────────────────────────────────────────────────
  Widget _buildInvoiceCard(InvoiceModel inv) {
    final invNum = inv.id.length > 8
        ? inv.id.substring(inv.id.length - 8)
        : inv.id;
    final (statusColor, statusBg, statusLabel) = _statusMeta(inv.status);
    final fmtDate = inv.dueDate != null
        ? '${inv.dueDate!.day.toString().padLeft(2, '0')}/${inv.dueDate!.month.toString().padLeft(2, '0')}/${inv.dueDate!.year}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showDetail(inv),
        borderRadius: BorderRadius.circular(14),
        splashColor: _violet100,
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _violet900.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left status bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        // Invoice icon
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _violet100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 20,
                            color: _violet700,
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INV-$invNum',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inv.customerName ?? inv.customerId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (fmtDate != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 11,
                                      color: _textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Due $fmtDate',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Rs.${inv.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 10),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice detail sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceDetailSheet extends StatelessWidget {
  const _InvoiceDetailSheet({required this.inv, required this.onVoided});
  final InvoiceModel inv;
  final VoidCallback onVoided;

  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _divider = Color(0xFFEEEBFA);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);
  static const _danger = Color(0xFFD93025);
  static const _dangerSoft = Color(0xFFFCECEB);
  static const _success = Color(0xFF0F7B0F);
  static const _successSoft = Color(0xFFE6F4EA);
  static const _warning = Color(0xFFBA7517);
  static const _warningSoft = Color(0xFFFAEEDA);

  static (Color, Color, String) _statusMeta(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return (_success, _successSoft, 'PAID');
      case 'partial':
        return (_warning, _warningSoft, 'PARTIAL');
      case 'voided':
        return (_textSecondary, _divider, 'VOIDED');
      default:
        return (_warning, _warningSoft, 'UNPAID');
    }
  }

  @override
  Widget build(BuildContext context) {
    final invNum = inv.id.length > 8
        ? inv.id.substring(inv.id.length - 8)
        : inv.id;
    final (statusColor, statusBg, statusLabel) = _statusMeta(inv.status);
    final fmtDate = inv.dueDate != null
        ? '${inv.dueDate!.day.toString().padLeft(2, '0')}/${inv.dueDate!.month.toString().padLeft(2, '0')}/${inv.dueDate!.year}'
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header row
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _violet100,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 24,
                  color: _violet700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INV-$invNum',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      inv.customerName ?? inv.customerId,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: _divider, height: 1),
          const SizedBox(height: 14),

          // Details grid
          _row('Amount', 'Rs.${inv.amount.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _row('Status', inv.status),
          if (fmtDate != null) ...[
            const SizedBox(height: 8),
            _row('Due Date', fmtDate),
          ],

          const SizedBox(height: 20),

          // Share button
          SizedBox(
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4C2DB8), Color(0xFF6C42F5)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B35D5).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final url = await InvoiceApi.share(inv.id);
                    if (context.mounted && url.isNotEmpty) {
                      AppSnackbar.success(context, 'Share link: $url');
                    }
                  } catch (e) {
                    if (context.mounted) ErrorHandler.show(context, e);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.share_outlined, size: 17),
                label: const Text(
                  'Share / Get Link',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ),

          // Void button
          if (inv.status.toLowerCase() != 'voided') ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Void Invoice',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    content: const Text(
                      'This will void the invoice and cannot be undone.',
                      style: TextStyle(color: _textSecondary, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _danger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Void',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  await InvoiceApi.voidInvoice(inv.id);
                  if (context.mounted) onVoided();
                } catch (e) {
                  if (context.mounted) ErrorHandler.show(context, e);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _danger.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block_rounded, size: 16, color: _danger),
                    const SizedBox(width: 8),
                    const Text(
                      'Void Invoice',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
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

  Widget _row(String label, String value) => Row(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: _textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Generate invoice sheet
// ─────────────────────────────────────────────────────────────────────────────

class _GenerateInvoiceSheet extends StatefulWidget {
  const _GenerateInvoiceSheet({required this.onGenerated});
  final VoidCallback onGenerated;

  @override
  State<_GenerateInvoiceSheet> createState() => _GenerateInvoiceSheetState();
}

class _GenerateInvoiceSheetState extends State<_GenerateInvoiceSheet> {
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet500 = Color(0xFF6C42F5);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _divider = Color(0xFFEEEBFA);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);

  List<CustomerModel> _customers = [];
  CustomerModel? _customer;
  DateTime _billingStart = DateTime.now();
  DateTime _billingEnd = DateTime.now().add(const Duration(days: 30));
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  // ── API (unchanged) ───────────────────────────────────────────────────────
  Future<void> _loadCustomers() async {
    if (_loaded) return;
    try {
      final res = await CustomerApi.list(limit: 100, status: 'active');
      final rawList = (res['data'] as List?) ?? [];
      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => CustomerModel.fromJson(e))
          .toList();
      if (mounted) {
        setState(() {
          _customers = list;
          _loaded = true;
          if (list.isNotEmpty && _customer == null) _customer = list.first;
        });
      }
    } catch (_) {}
  }

  Future<void> _generate() async {
    if (_customer == null) {
      AppSnackbar.error(context, 'Select a customer');
      return;
    }
    setState(() => _loading = true);
    try {
      await InvoiceApi.generate(
        customerId: _customer!.id,
        billingStart: _billingStart,
        billingEnd: _billingEnd,
      );
      if (mounted) {
        AppSnackbar.success(context, 'Invoice generated');
        widget.onGenerated();
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _violet100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: _violet700,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Generate Invoice',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Customer dropdown
            _label('Customer'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: _violet50,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CustomerModel>(
                  value: _customer,
                  isExpanded: true,
                  dropdownColor: _surface,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _textSecondary,
                  ),
                  hint: Text(
                    'Select customer',
                    style: TextStyle(
                      color: _textSecondary.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  items: _customers
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            '${c.name}  ·  ${c.phone}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _customer = v),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Billing dates
            _label('Billing Period'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _dateTile(
                    label: 'Start',
                    date: _billingStart,
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _billingStart,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => _billingStart = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateTile(
                    label: 'End',
                    date: _billingEnd,
                    icon: Icons.event_rounded,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _billingEnd,
                        firstDate: _billingStart,
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 2),
                        ),
                      );
                      if (d != null) setState(() => _billingEnd = d);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_violet700, _violet500],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: _violet600.withValues(alpha: 0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _loading
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
                            Icon(Icons.receipt_long_outlined, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Generate Invoice',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Row(
    children: [
      Container(
        width: 3,
        height: 12,
        decoration: BoxDecoration(
          color: _violet600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );

  Widget _dateTile({
    required String label,
    required DateTime date,
    required IconData icon,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _violet50,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _violet600),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
