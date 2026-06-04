class ReportSummary {
  const ReportSummary({
    required this.dailyRevenue,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    required this.activeSubscriptions,
    required this.pendingDeliveries,
    required this.overduePayments,
  });

  final double dailyRevenue;
  final double weeklyRevenue;
  final double monthlyRevenue;
  final int activeSubscriptions;
  final int pendingDeliveries;
  final int overduePayments;

  int? get totalCustomers => null;
}
