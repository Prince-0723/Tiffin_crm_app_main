final class FinanceStats {
  const FinanceStats({
    required this.processedCount,
    required this.processedAmount,
    required this.refundAmount,
    required this.netRevenue,
    required this.income,
    required this.expenses,
    required this.profit,
    required this.deposit,
  });

  final int processedCount;
  final double processedAmount;
  final double refundAmount;
  final double netRevenue;
  final double income;
  final double expenses;
  final double profit;
  final double deposit;

  static const zero = FinanceStats(
    processedCount: 0,
    processedAmount: 0,
    refundAmount: 0,
    netRevenue: 0,
    income: 0,
    expenses: 0,
    profit: 0,
    deposit: 0,
  );
}

