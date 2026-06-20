import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_handler.dart';
import '../data/income_api.dart';
import '../models/income_model.dart';

class _D {
  static const bg = Color(0xFF0E1020);
  static const surface = Color(0xFF1B1F2E);
  static const border = Color(0xFF2F3347);
  static const divider = Color(0xFF2F3347);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const violet100 = Color(0xFF241B42);
  static const violet50 = Color(0xFF141625);
}

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key, this.embeddedInFinanceShell = false});

  final bool embeddedInFinanceShell;

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  static final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  List<IncomeModel> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  static const int _pageSize = 20;
  int _total = 0;
  double _monthTotal = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  (String, String) _monthRange() {
    final now = DateTime.now();
    final from = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final last = DateTime(now.year, now.month + 1, 0);
    final to =
        '${last.year}-${last.month.toString().padLeft(2, '0')}-${last.day.toString().padLeft(2, '0')}';
    return (from, to);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
      });
    }
    try {
      final (from, to) = _monthRange();

      if (reset) {
        final bulk = await IncomeApi.list(
          page: 1,
          limit: 100,
          dateFrom: from,
          dateTo: to,
        );
        final monthSum = bulk.items.fold<double>(0, (s, i) => s + i.amount);
        if (!mounted) return;
        setState(() => _monthTotal = monthSum);
      }

      final res = await IncomeApi.list(
        page: _page,
        limit: _pageSize,
        dateFrom: from,
        dateTo: to,
      );
      if (!mounted) return;
      setState(() {
        _items = reset ? res.items : [..._items, ...res.items];
        _total = res.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.show(context, e);
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() => _load(reset: true);

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    _page += 1;
    try {
      final (from, to) = _monthRange();
      final res = await IncomeApi.list(
        page: _page,
        limit: _pageSize,
        dateFrom: from,
        dateTo: to,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...res.items];
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        _page -= 1;
        ErrorHandler.show(context, e);
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _confirmDelete(IncomeModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete income?'),
        content: Text('Remove "${e.source}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await IncomeApi.delete(e.id);
      if (mounted) {
        AppSnackbar.success(context, 'Income deleted');
        _load(reset: true);
      }
    } catch (err) {
      if (mounted) ErrorHandler.show(context, err);
    }
  }

  void _openAdd() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddIncomeSheet(
        onAdded: () {
          Navigator.pop(ctx);
          _load(reset: true);
        },
      ),
    );
  }

  double get _highestEntry => _items.isEmpty
      ? 0
      : _items.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

  double get _avgEntry => _items.isEmpty ? 0 : _monthTotal / _items.length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 120) {
                  _loadMore();
                }
                return false;
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  mq.padding.bottom + 80,
                ),
                children: [
                  _monthCard(),
                  const SizedBox(height: 14),
                  _sectionLabel('This month\'s entries'),
                  const SizedBox(height: 8),
                  if (_items.isEmpty) _emptyState() else ..._items.map(_tile),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          );

    return Scaffold(
      backgroundColor: isDark ? _D.bg : AppColors.background,
      appBar: widget.embeddedInFinanceShell
          ? null
          : AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              title: const Text('Income'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'income_fab_add',
        onPressed: _openAdd,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Income'),
      ),
      body: SafeArea(bottom: true, child: body),
    );
  }

  // ── Month card ────────────────────────────────────────────────────

  Widget _monthCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthName = DateFormat('MMMM yyyy').format(DateTime.now());
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? _D.surface : AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? Border.all(color: _D.border) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total income this month',
                    style: TextStyle(
                      color: isDark ? _D.textSecondary : AppColors.onPrimary.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? _D.violet100 : AppColors.primaryAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      monthName,
                      style: TextStyle(
                        color: isDark ? AppColors.primary : AppColors.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _fmt.format(_monthTotal),
                style: TextStyle(
                  color: isDark ? _D.textPrimary : AppColors.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Across ${_items.length} ${_items.length == 1 ? 'entry' : 'entries'}',
                style: TextStyle(
                  color: isDark ? _D.textSecondary : AppColors.onPrimary.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Highest entry',
                _highestEntry,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('Avg per entry', _avgEntry, isDark ? AppColors.primaryLight : AppColors.primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, double value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? _D.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? _D.border : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? _D.textSecondary : AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            _fmt.format(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: isDark ? _D.textSecondary : AppColors.textSecondary,
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────

  Widget _emptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 52,
            color: isDark ? _D.textSecondary.withValues(alpha: 0.4) : AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            'No income entries',
            style: TextStyle(fontSize: 14, color: isDark ? _D.textSecondary : AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Income tile ───────────────────────────────────────────────────

  Widget _tile(IncomeModel e) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.22,
          children: [
            CustomSlidableAction(
              onPressed: (_) => _confirmDelete(e),
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              borderRadius: BorderRadius.circular(12),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 22),
                  SizedBox(height: 4),
                  Text('Delete', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? _D.surface : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? _D.border : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.success.withValues(alpha: 0.15) : AppColors.successChipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.source,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? _D.textPrimary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.yMMMd().format(e.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? _D.textSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? _D.border : AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e.paymentMethod ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? _D.textSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _fmt.format(e.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Income Sheet ──────────────────────────────────────────────

class AddIncomeSheet extends StatefulWidget {
  const AddIncomeSheet({super.key, required this.onAdded});

  final VoidCallback onAdded;

  @override
  State<AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<AddIncomeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _sourceCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _payment = 'cash';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await IncomeApi.create({
        'source': _sourceCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text.trim()),
        'date': _date.toIso8601String().split('T').first,
        'paymentMethod': _payment,
        if (_refCtrl.text.trim().isNotEmpty)
          'referenceId': _refCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      if (mounted) {
        AppSnackbar.success(context, 'Income added');
        widget.onAdded();
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? _D.surface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: mq.viewInsets.bottom + mq.padding.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? _D.border : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add income',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? _D.textPrimary : null,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sourceCtrl,
                  style: TextStyle(color: isDark ? _D.textPrimary : null),
                  decoration: InputDecoration(
                    labelText: 'Source',
                    labelStyle: TextStyle(color: isDark ? _D.textSecondary : null),
                    hintText: 'e.g. Subscription Payment, Refund, Manual',
                    hintStyle: TextStyle(color: isDark ? _D.textSecondary.withValues(alpha: 0.5) : null),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter source' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: isDark ? _D.textPrimary : null),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: isDark ? _D.textSecondary : null),
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(color: isDark ? _D.textPrimary : null),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter valid amount';
                    }
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _payment,
                  dropdownColor: isDark ? _D.surface : null,
                  style: TextStyle(color: isDark ? _D.textPrimary : null),
                  decoration: InputDecoration(
                    labelText: 'Payment method',
                    labelStyle: TextStyle(color: isDark ? _D.textSecondary : null),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'cash',
                      child: Text('Cash', style: TextStyle(color: isDark ? _D.textPrimary : null)),
                    ),
                    DropdownMenuItem(
                      value: 'upi',
                      child: Text('UPI', style: TextStyle(color: isDark ? _D.textPrimary : null)),
                    ),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Bank transfer', style: TextStyle(color: isDark ? _D.textPrimary : null)),
                    ),
                    DropdownMenuItem(
                      value: 'card',
                      child: Text('Card', style: TextStyle(color: isDark ? _D.textPrimary : null)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _payment = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refCtrl,
                  style: TextStyle(color: isDark ? _D.textPrimary : null),
                  decoration: InputDecoration(
                    labelText: 'Reference ID (optional)',
                    labelStyle: TextStyle(color: isDark ? _D.textSecondary : null),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date', style: TextStyle(color: isDark ? _D.textPrimary : null)),
                  subtitle: Text(DateFormat.yMMMd().format(_date), style: TextStyle(color: isDark ? _D.textSecondary : null)),
                  trailing: Icon(Icons.calendar_today_rounded, size: 20, color: isDark ? _D.textSecondary : null),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? _D.textPrimary : null),
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    labelStyle: TextStyle(color: isDark ? _D.textSecondary : null),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text('Save income'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

