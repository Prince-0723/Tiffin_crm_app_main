import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../reports/data/report_api.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _period = 'monthly';
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _todayPayload = {};
  List<dynamic> _todayOrders = [];
  List<dynamic> _expiring = [];
  Map<String, dynamic> _pending = {};
  bool _loading = true;

  static final _rupee = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _count = NumberFormat.decimalPattern('en_IN');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ReportApi.getSummary(period: _period),
        ReportApi.getTodayDeliveriesPayload(),
        ReportApi.getExpiringSubscriptions(days: 7),
        ReportApi.getPendingPayments(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _todayPayload = results[1] as Map<String, dynamic>;
        final orders = _todayPayload['orders'];
        _todayOrders = orders is List ? List<dynamic>.from(orders) : [];
        final exp = results[2];
        _expiring = exp is List ? List<dynamic>.from(exp) : [];
        _pending = results[3] as Map<String, dynamic>;
      });
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPeriodChanged(String? v) {
    if (v == null || v == _period) return;
    setState(() => _period = v);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: AppColors.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(context).padding.bottom + 32,
                ),
                children: [
                  Text(
                    'Generate operational reports for the whole system. Choose a period for revenue and delivery metrics.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'daily',
                          label: Text('Daily'),
                          icon: Icon(Icons.today_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: 'weekly',
                          label: Text('Weekly'),
                          icon: Icon(Icons.date_range_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: 'monthly',
                          label: Text('Monthly'),
                          icon: Icon(Icons.calendar_month_outlined, size: 18),
                        ),
                      ],
                      selected: {_period},
                      onSelectionChanged: (s) {
                        if (s.isEmpty) return;
                        _onPeriodChanged(s.first);
                      },
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.onPrimary
                              : AppColors.onSurface,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.primary
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Summary'),
                  const SizedBox(height: 8),
                  if (_summary.isEmpty)
                    _emptyCard(theme, 'No summary could be loaded.')
                  else
                    _summaryCard(theme),
                  const SizedBox(height: 24),
                  const SectionHeader(title: "Today's deliveries"),
                  const SizedBox(height: 8),
                  _todayDeliveriesSection(theme),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Expiring subscriptions'),
                  const SizedBox(height: 4),
                  Text(
                    'Active subscriptions ending in the next 7 days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_expiring.isEmpty)
                    _emptyCard(theme, 'No subscriptions expiring in this window.')
                  else
                    ..._expiring.map((e) => _expiringTile(theme, e)),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Pending payments'),
                  const SizedBox(height: 8),
                  _pendingPaymentsSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(ThemeData theme) {
    final rev = _num(_summary['revenue']);
    final subs = _int(_summary['activeSubscriptions']);
    final del = _int(_summary['deliveries']);
    final periodLabel = _periodLabel(_summary['period']?.toString());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _metricRow(
              theme,
              'Active subscriptions',
              _count.format(subs),
              Icons.assignment_outlined,
            ),
            const Divider(height: 20),
            _metricRow(
              theme,
              'Captured revenue',
              _rupee.format(rev),
              Icons.currency_rupee_rounded,
            ),
            const Divider(height: 20),
            _metricRow(
              theme,
              'Deliveries completed',
              _count.format(del),
              Icons.local_shipping_outlined,
            ),
            const Divider(height: 20),
            _metricRow(
              theme,
              'Reporting period',
              periodLabel,
              Icons.schedule_outlined,
              valueEmphasis: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon, {
    bool valueEmphasis = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary.withValues(alpha: 0.85)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: valueEmphasis ? FontWeight.w700 : FontWeight.w600,
              color: valueEmphasis ? AppColors.onSurface : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _todayDeliveriesSection(ThemeData theme) {
    final total = _int(_todayPayload['total']);
    final dateStr = _todayPayload['date']?.toString();
    final rawSummary = _todayPayload['summary'];
    final statusCounts = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary)
        : <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr != null ? 'Date: $dateStr (UTC)' : 'Today',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$total orders scheduled',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (statusCounts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statusCounts.entries.map((e) {
              return Chip(
                label: Text(
                  '${_humanizeStatus(e.key)} · ${e.value}',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.5),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 10),
        if (_todayOrders.isEmpty)
          _emptyCard(theme, 'No delivery orders for today.')
        else
          ..._todayOrders.map((e) => _deliveryTile(theme, e)),
      ],
    );
  }

  Widget _deliveryTile(ThemeData theme, dynamic raw) {
    final map = _asMap(raw);
    final customer = map['customerId'];
    String name = 'Customer';
    if (customer is Map) {
      name = customer['name']?.toString().trim() ?? name;
    }
    final status = map['status']?.toString() ?? '';
    final slot = map['deliverySlot']?.toString() ?? map['slot']?.toString() ?? '';
    final staff = map['deliveryStaffId'];
    String? staffName;
    if (staff is Map) {
      staffName = staff['name']?.toString();
    }
    final owner = map['ownerId'];
    String? vendor;
    if (owner is Map) {
      vendor = owner['businessName']?.toString().trim();
      if (vendor == null || vendor.isEmpty) {
        vendor = owner['ownerName']?.toString().trim();
      }
    }

    final sub = <String>[
      if (vendor != null && vendor.isNotEmpty) vendor,
      if (slot.isNotEmpty) slot,
      if (staffName != null && staffName.isNotEmpty) staffName,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          name,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: sub.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  sub,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _humanizeStatus(status),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _expiringTile(ThemeData theme, dynamic raw) {
    final map = _asMap(raw);
    final plan = map['planId'];
    String planName = 'Plan';
    if (plan is Map) {
      planName = plan['planName']?.toString() ?? planName;
    }
    final cust = map['customerId'];
    String custName = '—';
    if (cust is Map) {
      custName = cust['name']?.toString() ?? custName;
    }
    DateTime? end;
    final ed = map['endDate'];
    if (ed is String) end = DateTime.tryParse(ed);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: ListTile(
        title: Text(
          planName,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$custName${end != null ? ' · Ends ${_shortDate(end)}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        leading: Icon(Icons.event_outlined, color: AppColors.warning),
      ),
    );
  }

  Widget _pendingPaymentsSection(ThemeData theme) {
    final unpaid = _pending['unpaidInvoices'];
    final neg = _pending['negativeBalanceCustomers'];
    final invoiceItems = unpaid is Map ? unpaid['items'] : null;
    final negItems = neg is Map ? neg['items'] : null;
    final invList = invoiceItems is List ? invoiceItems : <dynamic>[];
    final negList = negItems is List ? negItems : <dynamic>[];

    if (invList.isEmpty && negList.isEmpty) {
      return _emptyCard(theme, 'No unpaid invoices or negative wallet balances.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (invList.isNotEmpty) ...[
          Text(
            'Unpaid / partial invoices',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...invList.map((e) => _invoiceTile(theme, e)),
          const SizedBox(height: 16),
        ],
        if (negList.isNotEmpty) ...[
          Text(
            'Customers with negative balance',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...negList.map((e) => _negativeBalanceTile(theme, e)),
        ],
      ],
    );
  }

  Widget _invoiceTile(ThemeData theme, dynamic raw) {
    final map = _asMap(raw);
    final cust = map['customerId'];
    String name = 'Customer';
    if (cust is Map) name = cust['name']?.toString() ?? name;
    final amt = _num(map['amount'] ?? map['totalAmount']);
    final ps = map['paymentStatus']?.toString() ?? '';
    final owner = map['ownerId'];
    String? vendor;
    if (owner is Map) {
      vendor = owner['businessName']?.toString() ?? owner['ownerName']?.toString();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: vendor != null && vendor.isNotEmpty
            ? Text(vendor, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _rupee.format(amt),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              ps,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _negativeBalanceTile(ThemeData theme, dynamic raw) {
    final map = _asMap(raw);
    final name = map['name']?.toString() ?? 'Customer';
    final bal = _num(map['balance']);
    final owner = map['ownerId'];
    String? vendor;
    if (owner is Map) {
      vendor = owner['businessName']?.toString() ?? owner['ownerName']?.toString();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: vendor != null && vendor.isNotEmpty
            ? Text(vendor, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
            : null,
        trailing: Text(
          _rupee.format(bal),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(ThemeData theme, String text) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return {};
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  return 0;
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return 0;
}

String _periodLabel(String? p) {
  switch (p) {
    case 'daily':
      return 'Today';
    case 'weekly':
      return 'Last 7 days';
    case 'monthly':
      return 'Last 30 days';
    default:
      return p ?? '—';
  }
}

String _humanizeStatus(String raw) {
  if (raw.isEmpty) return raw;
  return raw
      .split('_')
      .map(
        (w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1) : ''}',
      )
      .join(' ');
}

String _shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
