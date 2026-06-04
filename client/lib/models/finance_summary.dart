final class FinanceSummary {
  FinanceSummary({
    required this.revenue,
    required this.expenses,
    required this.incomes,
    required this.deposit,
    required this.processed,
    required this.refund,
    required this.manual,
    required this.profit,
    required this.daily,
  });

  final double revenue;
  final double expenses;
  final double incomes;
  final double deposit;
  final double processed;
  final double refund;
  final double manual;
  final double profit;
  final List<DailyEntry> daily;

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    return FinanceSummary(
      revenue: _toDouble(json['revenue']),
      expenses: _toDouble(json['expenses']),
      incomes: _toDouble(json['incomes']),
      deposit: _toDouble(json['deposit'] ?? json['deposits']),
      processed: _toDouble(json['processed']),
      refund: _toDouble(json['refund'] ?? json['refunds']),
      manual: _toDouble(json['manual']),
      profit: _toDouble(json['profit']),
      daily: const [],
    );
  }

  static final empty = FinanceSummary(
    revenue: 0,
    expenses: 0,
    incomes: 0,
    deposit: 0,
    processed: 0,
    refund: 0,
    manual: 0,
    profit: 0,
    daily: [],
  );

  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
}

final class DailyEntry {
  const DailyEntry({
    required this.date,
    required this.processed,
    required this.processedCount,
    required this.income,
    required this.deposit,
    required this.expense,
    required this.refund,
    required this.manual,
  });

  final String date; // "DD/MM"
  final double processed;
  /// Delivered daily orders count for this calendar day (UTC bucket from API).
  final int processedCount;
  final double income;
  final double deposit;
  final double expense;
  final double refund;
  final double manual;

  factory DailyEntry.fromJson(Map<String, dynamic> json) {
    return DailyEntry(
      date: json['date']?.toString() ?? '',
      processed: _toDouble(json['processed']),
      processedCount: (json['processedCount'] as num?)?.toInt() ??
          (json['processed_count'] as num?)?.toInt() ??
          0,
      income: _toDouble(json['income']),
      deposit: _toDouble(json['deposit']),
      expense: _toDouble(json['expense']),
      refund: _toDouble(json['refund']),
      manual: _toDouble(json['manual']),
    );
  }

  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
}

final class DailyFinanceRow {
  const DailyFinanceRow({
    required this.date,
    required this.processedCount,
    required this.processedAmount,
    required this.incomes,
    required this.deposits,
    required this.refund,
    required this.expenses,
    required this.manual,
  });

  final DateTime date;
  final int processedCount;
  final double processedAmount;
  final double incomes;
  final double deposits;
  final double refund;
  final double expenses;
  final double manual;

  factory DailyFinanceRow.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString() ?? '';
    final parsed = DateTime.tryParse(rawDate);
    final date = parsed ?? DateTime.fromMillisecondsSinceEpoch(0);

    final processedCount =
        (json['processedCount'] as num?)?.toInt() ??
        (json['processed_count'] as num?)?.toInt() ??
        0;

    // Backend calendar currently returns { revenue, expenses, net_profit }.
    // We map revenue -> processedAmount for the screen's "Processed (₹X)" display.
    final processedAmount =
        _toDouble(json['processedAmount'] ?? json['processed_amount'] ?? json['revenue']);

    final incomes = _toDouble(json['incomes'] ?? json['income']);
    final deposits = _toDouble(json['deposits'] ?? json['deposit']);
    final refund = _toDouble(json['refund'] ?? json['refunds']);
    final expenses = _toDouble(json['expenses']);
    final manual = _toDouble(json['manual']);

    return DailyFinanceRow(
      date: DateTime(date.year, date.month, date.day),
      processedCount: processedCount,
      processedAmount: processedAmount,
      incomes: incomes,
      deposits: deposits,
      refund: refund,
      expenses: expenses,
      manual: manual,
    );
  }

  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
}

enum FinanceTransactionKind { income, expense }

final class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.kind,
    required this.date,
    required this.amount,
    required this.title,
  });

  final String id;
  final FinanceTransactionKind kind;
  final DateTime date;
  final double amount;
  final String title; // e.g. Income source / Expense title

  bool get isCredit => kind == FinanceTransactionKind.income;
  String get financeType => isCredit ? 'income' : 'expense';
  String get type => isCredit ? 'credit' : 'debit';
}

