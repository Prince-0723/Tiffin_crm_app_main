class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.customerId,
    required this.planId,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.autoRenewal = false,
  });

  final String id;
  final String customerId;
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final bool autoRenewal;
}
