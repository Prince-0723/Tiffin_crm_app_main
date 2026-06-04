import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_handler.dart';
import '../data/expense_api.dart';
import '../models/expense_model.dart';

IconData expenseCategoryIcon(String category) {
  switch (category) {
    case 'food':
      return Icons.restaurant_rounded;
    case 'transport':
      return Icons.directions_car_rounded;
    case 'salary':
      return Icons.people_rounded;
    case 'rent':
      return Icons.home_rounded;
    case 'utilities':
      return Icons.bolt_rounded;
    case 'marketing':
      return Icons.campaign_rounded;
    case 'equipment':
      return Icons.build_rounded;
    case 'maintenance':
      return Icons.handyman_rounded;
    default:
      return Icons.category_rounded;
  }
}

Color expenseCategoryColor(String category) {
  switch (category) {
    case 'food':
      return AppColors.warning;
    case 'transport':
      return AppColors.primaryAccent;
    case 'salary':
      return AppColors.secondary;
    case 'rent':
      return AppColors.onSurface;
    case 'utilities':
      return AppColors.processingChipText;
    case 'marketing':
      return AppColors.pendingChipText;
    case 'equipment':
      return AppColors.outForDeliveryChipText;
    case 'maintenance':
      return AppColors.textSecondary;
    default:
      return AppColors.primary;
  }
}

Color expenseCategoryBg(String category) {
  switch (category) {
    case 'food':
      return const Color(0xFFFAEEDA);
    case 'transport':
      return const Color(0xFFE6F1FB);
    case 'salary':
      return const Color(0xFFEAF3DE);
    case 'rent':
      return const Color(0xFFEAF3DE);
    case 'utilities':
      return const Color(0xFFEEEDFE);
    case 'marketing':
      return const Color(0xFFFBEAF0);
    case 'equipment':
      return const Color(0xFFFAECE7);
    case 'maintenance':
      return const Color(0xFFF1EFE8);
    default:
      return const Color(0xFFE6F1FB);
  }
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, this.embeddedInFinanceShell = false});

  final bool embeddedInFinanceShell;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  static final _fmtMoney =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  final _searchCtrl = TextEditingController();
  List<ExpenseModel> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  static const int _pageSize = 20;
  int _total = 0;

  Map<String, dynamic>? _summary;
  String _period = 'all';
  DateTimeRange? _customRange;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  (String?, String?) _dateQuery() {
    final now = DateTime.now();
    switch (_period) {
      case 'week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        final s = DateTime(start.year, start.month, start.day);
        final e = DateTime(now.year, now.month, now.day);
        return (
          '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}',
          '${e.year}-${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')}',
        );
      case 'month':
        final s = DateTime(now.year, now.month, 1);
        final e = DateTime(now.year, now.month + 1, 0);
        return (
          '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}',
          '${e.year}-${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')}',
        );
      case 'custom':
        if (_customRange == null) return (null, null);
        final a = _customRange!.start;
        final b = _customRange!.end;
        return (
          '${a.year}-${a.month.toString().padLeft(2, '0')}-${a.day.toString().padLeft(2, '0')}',
          '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
        );
      default:
        return (null, null);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
      });
    }
    try {
      final (df, dt) = _dateQuery();
      final res = await ExpenseApi.list(
        page: _page,
        limit: _pageSize,
        category: _categoryFilter,
        dateFrom: df,
        dateTo: dt,
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
      );
      Map<String, dynamic>? sum;
      try {
        sum = await ExpenseApi.summary();
      } catch (_) {
        sum = _summary;
      }
      if (!mounted) return;
      setState(() {
        _items = reset ? res.items : [..._items, ...res.items];
        _total = res.total;
        if (sum != null) _summary = sum;
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
      final (df, dt) = _dateQuery();
      final res = await ExpenseApi.list(
        page: _page,
        limit: _pageSize,
        category: _categoryFilter,
        dateFrom: df,
        dateTo: dt,
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
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

  Future<void> _confirmDelete(ExpenseModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('Remove "${e.title}"?'),
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
      await ExpenseApi.delete(e.id);
      if (mounted) {
        AppSnackbar.success(context, 'Expense deleted');
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
      builder: (ctx) => AddExpenseSheet(
        onAdded: () {
          Navigator.pop(ctx);
          _load(reset: true);
        },
      ),
    );
  }

  double _sumFromSummary(String key) {
    final v = _summary?[key];
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  List<Map<String, dynamic>> _categoryBreakdown() {
    final raw = _summary?['categoryBreakdown'];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scrollBody = _loading
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
                  _summaryRow(),
                  const SizedBox(height: 12),
                  _periodChips(),
                  const SizedBox(height: 10),
                  _searchField(),
                  const SizedBox(height: 10),
                  _categoryChips(),
                  const SizedBox(height: 14),
                  if (_categoryBreakdown().isNotEmpty) ...[
                    _sectionLabel('Category breakdown'),
                    const SizedBox(height: 8),
                    ..._categoryBreakdown().map(_breakdownTile),
                    const SizedBox(height: 6),
                  ],
                  if (_items.isEmpty)
                    _emptyState()
                  else ...[
                    _sectionLabel('Recent expenses'),
                    const SizedBox(height: 8),
                    ..._items.map(_expenseTile),
                  ],
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
      backgroundColor: AppColors.background,
      appBar: widget.embeddedInFinanceShell
          ? null
          : AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              title: const Text('Expenses'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expenses_fab_add',
        onPressed: _openAdd,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
      body: SafeArea(bottom: true, child: scrollBody),
    );
  }

  // ── Summary ──────────────────────────────────────────────────────

  Widget _summaryRow() {
    final exp = _sumFromSummary('totalExpenseThisMonth');
    final inc = _sumFromSummary('totalIncomeThisMonth');
    final net = _sumFromSummary('netBalance');
    return Row(
      children: [
        Expanded(
          child: _sumCard('Expense', exp, AppColors.errorContainer,
              AppColors.error),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _sumCard(
              'Income', inc, AppColors.successChipBg, AppColors.success),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _sumCard(
            'Balance',
            net,
            AppColors.primaryContainer,
            net >= 0 ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _sumCard(String label, double value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _fmtMoney.format(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ── Period chips ─────────────────────────────────────────────────

  Widget _periodChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pChip('All', 'all'),
        _pChip('This Week', 'week'),
        _pChip('This Month', 'month'),
        _pChip('Custom', 'custom'),
      ],
    );
  }

  Widget _pChip(String label, String value) {
    final sel = _period == value;
    return FilterChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) async {
        if (value == 'custom') {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(DateTime.now().year - 1),
            lastDate: DateTime(DateTime.now().year + 1),
            initialDateRange: _customRange ??
                DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 7)),
                  end: DateTime.now(),
                ),
          );
          if (range != null) {
            setState(() {
              _period = 'custom';
              _customRange = range;
            });
            _load(reset: true);
          }
        } else {
          setState(() => _period = value);
          _load(reset: true);
        }
      },
    );
  }

  // ── Search ───────────────────────────────────────────────────────

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      onSubmitted: (_) => _load(reset: true),
      decoration: InputDecoration(
        hintText: 'Search by title',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  // ── Category filter chips ─────────────────────────────────────────

  Widget _categoryChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _catChip('All', null),
          ...ExpenseModel.categories.map((c) => _catChip(c, c)),
        ],
      ),
    );
  }

  Widget _catChip(String label, String? value) {
    final sel = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) {
          setState(() => _categoryFilter = value);
          _load(reset: true);
        },
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
    );
  }

  // ── Category breakdown ────────────────────────────────────────────

  Widget _breakdownTile(Map<String, dynamic> row) {
    final cat = row['category']?.toString() ?? 'misc';
    final total = (row['total'] is num)
        ? (row['total'] as num).toDouble()
        : double.tryParse('${row['total']}') ?? 0;
    final pct = (row['percentage'] is num)
        ? (row['percentage'] as num).toDouble()
        : double.tryParse('${row['percentage']}') ?? 0;
    final icon = expenseCategoryIcon(cat);
    final col = expenseCategoryColor(cat);
    final bg = expenseCategoryBg(cat);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: col),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cat,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                _fmtMoney.format(total),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: AppColors.primaryContainer,
                color: col,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 52,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            'No expenses found',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Expense tile ──────────────────────────────────────────────────

  Widget _expenseTile(ExpenseModel e) {
    final col = expenseCategoryColor(e.category);
    final bg = expenseCategoryBg(e.category);
    final icon = expenseCategoryIcon(e.category);

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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: col, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.yMMMd().format(e.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmtMoney.format(e.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e.category,
                      style: TextStyle(fontSize: 10, color: col),
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

// ── Add Expense Sheet ─────────────────────────────────────────────

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key, required this.onAdded});

  final VoidCallback onAdded;

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _category;
  String _payment = 'cash';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _tagsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await ExpenseApi.create({
        'title': _titleCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text.trim()),
        'category': _category,
        'date': _date.toIso8601String().split('T').first,
        'paymentMethod': _payment,
        if (_notesCtrl.text.trim().isNotEmpty)
          'notes': _notesCtrl.text.trim(),
        if (tags.isNotEmpty) 'tags': tags,
      });
      if (mounted) {
        AppSnackbar.success(context, 'Expense added');
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
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add expense',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
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
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ExpenseModel.categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(expenseCategoryIcon(c), size: 18),
                              const SizedBox(width: 8),
                              Text(c),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) => v == null ? 'Select category' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _payment,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('Bank transfer')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                  ],
                  onChanged: (v) => setState(() => _payment = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat.yMMMd().format(_date)),
                  trailing:
                      const Icon(Icons.calendar_today_rounded, size: 20),
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
                  controller: _tagsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
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
                      : const Text('Save expense'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}