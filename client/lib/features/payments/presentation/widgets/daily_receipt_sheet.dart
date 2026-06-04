import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../services/pdf_download_service.dart';
import '../../data/invoice_api.dart';
import '../../utils/receipt_pdf_generator.dart';

/// Per-day meal receipt preview (GET /invoices/daily).
class DailyReceiptSheet extends StatefulWidget {
  const DailyReceiptSheet({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.initialDate,
  });

  final String customerId;
  final String customerName;
  final DateTime initialDate;

  @override
  State<DailyReceiptSheet> createState() => _DailyReceiptSheetState();
}

class _DailyReceiptSheetState extends State<DailyReceiptSheet> {
  late DateTime _date;
  Map<String, dynamic>? _receiptData;
  bool _loading = true;
  bool _downloading = false;
  bool _failed = false;

  static final _df = DateFormat('dd/MM/yyyy');
  static final _dfApi = DateFormat('yyyy-MM-dd');
  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  static const double _radius = 14;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final m = await InvoiceApi.getDailyReceipt(
        customerId: widget.customerId,
        date: _date,
      );
      if (mounted) setState(() => _receiptData = m);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Saves receipt PDF next to Downloads / Documents and opens it in the viewer.
  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final pdfBytes = await ReceiptPdfGenerator.generateReceiptPdf(
        customerName: widget.customerName,
        customerId: widget.customerId,
        date: _date,
        items: _pdfItems(),
        totalAmount: _totalAmount(),
        paymentStatus: _paymentStatus(),
        businessName: _businessName(),
      );
      final dateStr = _date.toIso8601String().split('T').first;
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: 'Receipt-${widget.customerId}-$dateStr',
        );
        return;
      }
      await PdfDownloadService.saveBytesAndOpen(
        context: context,
        bytes: pdfBytes,
        fileName: 'Receipt_${widget.customerId}_$dateStr.pdf',
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not generate PDF');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// Shares the generated PDF with available apps.
  Future<void> _shareReceipt() async {
    try {
      final pdfBytes = await ReceiptPdfGenerator.generateReceiptPdf(
        customerName: widget.customerName,
        customerId: widget.customerId,
        date: _date,
        items: _pdfItems(),
        totalAmount: _totalAmount(),
        paymentStatus: _paymentStatus(),
        businessName: _businessName(),
      );
      final dateStr = _date.toIso8601String().split('T').first;
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Receipt-${widget.customerId}-$dateStr.pdf',
      );
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    }
  }

  List<Map<String, dynamic>> _pdfItems() {
    final d = _receiptData;
    if (d == null) return const [];
    final rows = <Map<String, dynamic>>[];
    final deliveries = d['deliveries'];
    if (deliveries is List) {
      for (final slot in deliveries) {
        if (slot is! Map) continue;
        final slotMap = Map<String, dynamic>.from(slot);
        final items = slotMap['items'];
        if (items is List && items.isNotEmpty) {
          for (final it in items) {
            if (it is! Map) continue;
            final m = Map<String, dynamic>.from(it);
            rows.add(<String, dynamic>{
              'name': m['name'] ?? m['itemName'] ?? slotMap['slot'] ?? 'Item',
              'quantity': m['quantity'] ?? 1,
              'price': m['total'] ?? m['unitPrice'] ?? 0,
            });
          }
        } else {
          rows.add(<String, dynamic>{
            'name': slotMap['slot'] ?? 'Meal',
            'quantity': 1,
            'price': 0,
          });
        }
      }
    }
    return rows;
  }

  double _totalAmount() {
    final d = _receiptData;
    if (d == null) return 0;
    final summary = d['summary'];
    if (summary is Map) {
      final g = summary['grandTotal'];
      if (g is num) return g.toDouble();
      return double.tryParse('$g') ?? 0;
    }
    final g = d['grandTotal'];
    if (g is num) return g.toDouble();
    return double.tryParse('$g') ?? 0;
  }

  String _paymentStatus() {
    final d = _receiptData;
    if (d == null) return '';
    final summary = d['summary'];
    if (summary is Map) {
      final ps = summary['paymentStatus']?.toString();
      if (ps != null && ps.isNotEmpty) return ps;
      // Older backends without paymentStatus — mirror subscription vs cash logic.
      final grand = _num(summary['grandTotal'] ?? d['grandTotal']);
      final due = _num(summary['dueAmount'] ?? d['dueAmount']);
      final sub = _num(
        summary['subscriptionDeductedToday'] ?? d['subscriptionDeductedToday'],
      );
      final paid = _num(summary['paidAmount'] ?? d['paidAmount']);
      if (grand <= 0.01) return '—';
      if (due <= 0.01) {
        if (paid > 0.01 && sub > 0.01) return 'Settled';
        if (paid > 0.01) return 'Paid';
        return 'Covered by subscription';
      }
      if (sub > 0.01 || paid > 0.01) return 'Partially settled';
      return 'Pending';
    }
    return d['paymentStatus']?.toString() ?? '';
  }

  String _businessName() {
    final d = _receiptData;
    if (d == null) return 'Tiffin Service';
    final vendor = d['vendor'];
    if (vendor is Map) {
      return vendor['businessName']?.toString() ?? 'Tiffin Service';
    }
    return 'Tiffin Service';
  }

  void _prevDay() {
    setState(() => _date = _date.subtract(const Duration(days: 1)));
    _fetch();
  }

  void _nextDay() {
    setState(() => _date = _date.add(const Duration(days: 1)));
    _fetch();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _fetch();
    }
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: mq.viewInsets.bottom + mq.padding.bottom + 12,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Daily receipt',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_failed)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load receipt.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _fetch,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _dateNav(theme),
                      const SizedBox(height: 16),
                      _receiptBody(theme),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _shareReceipt,
                              icon: const Icon(Icons.share_outlined, size: 16),
                              label: const Text('Share'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7C3AED),
                                side: const BorderSide(
                                  color: Color(0xFF7C3AED),
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _downloading ? null : _downloadPdf,
                              icon: _downloading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.download_outlined, size: 16),
                              label: Text(_downloading ? 'Saving...' : 'Download PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B3FE4),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        kIsWeb
                            ? 'Download saves the PDF to your browser download folder.'
                            : 'Download saves the PDF under Downloads / Documents and opens it.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _dateNav(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _prevDay,
            icon: Icon(Icons.chevron_left_rounded, color: AppColors.primary),
            label: Text(
              'Prev',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _df.format(_date),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _nextDay,
            icon: Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            label: Text(
              'Next',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptBody(ThemeData theme) {
    final d = _receiptData;
    if (d == null) return const SizedBox.shrink();

    final custRaw = d['customer'];
    final sumRaw = d['summary'];
    final vendorRaw = d['vendor'];
    final receiptRaw = d['receipt'];

    final cust = custRaw is Map
        ? Map<String, dynamic>.from(custRaw)
        : const <String, dynamic>{};
    final summary = sumRaw is Map
        ? Map<String, dynamic>.from(sumRaw)
        : const <String, dynamic>{};
    final vendor = vendorRaw is Map
        ? Map<String, dynamic>.from(vendorRaw)
        : const <String, dynamic>{};
    final receipt = receiptRaw is Map
        ? Map<String, dynamic>.from(receiptRaw)
        : const <String, dynamic>{};

    final name = cust['name']?.toString() ?? '—';
    final phone = cust['phone']?.toString() ?? '—';
    final addr = cust['address']?.toString() ?? '—';
    final dateStr =
        receipt['date']?.toString() ??
        d['date']?.toString() ??
        _dfApi.format(_date);
    final receiptNo = receipt['receiptNumber']?.toString();
    final deliveries = (d['deliveries'] is List) ? d['deliveries'] as List : [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                size: 28,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            vendor['businessName']?.toString() ?? 'Company',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (receiptNo != null && receiptNo.isNotEmpty && receiptNo != '—')
            Text(
              'Receipt #$receiptNo',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            dateStr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'BILL TO',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            phone,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            addr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          if (deliveries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No deliveries recorded for this date.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            for (final slot in deliveries)
              if (slot is Map) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${slot['slot'] ?? 'Meal'}'.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _itemsTable(theme, slot['items']),
                const SizedBox(height: 14),
              ],
          Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 8),
          _line(theme, 'Subtotal', _num(summary['subtotal'] ?? d['subtotal'])),
          _line(theme, 'Tax', _num(summary['taxAmount'] ?? d['tax'])),
          _line(
            theme,
            'Grand Total',
            _num(summary['grandTotal'] ?? d['grandTotal']),
            bold: true,
          ),
          _line(
            theme,
            'Deducted from subscription',
            _num(
              summary['subscriptionDeductedToday'] ??
                  d['subscriptionDeductedToday'],
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 6),
          _line(
            theme,
            'Paid (cash/online)',
            _num(summary['paidAmount'] ?? d['paidAmount']),
          ),
          _line(
            theme,
            'This receipt due',
            _num(summary['dueAmount'] ?? d['dueAmount']),
          ),
          _line(
            theme,
            'Account running balance',
            _num(summary['runningBalance'] ?? d['runningBalance']),
          ),
        ],
      ),
    );
  }

  Widget _itemsTable(ThemeData theme, dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      return Text(
        '—',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.1),
        1: FlexColumnWidth(0.9),
        2: FlexColumnWidth(1.1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          children: [
            _cell(theme, 'Item', h: true),
            _cell(theme, 'Qty', h: true),
            _cell(theme, 'Total', h: true),
          ],
        ),
        ...raw.map((e) {
          if (e is! Map) {
            return TableRow(
              children: [const SizedBox(), const SizedBox(), const SizedBox()],
            );
          }
          final it = Map<String, dynamic>.from(e);
          final itemName = it['name']?.toString() ?? '—';
          final qty = it['quantity'] ?? '—';
          final total = _num(it['total']);
          return TableRow(
            children: [
              _cell(theme, itemName),
              _cell(theme, '$qty'),
              _cell(theme, _money.format(total)),
            ],
          );
        }),
      ],
    );
  }

  Widget _cell(ThemeData theme, String t, {bool h = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        t,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: h ? 11 : 12.5,
          fontWeight: h ? FontWeight.w700 : FontWeight.w500,
          color: h ? AppColors.textPrimary : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _line(ThemeData theme, String label, double v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            _money.format(v),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
