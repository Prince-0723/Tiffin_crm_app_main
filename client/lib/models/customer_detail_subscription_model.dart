/// Active plan card for the Meal Plan tab.
class CustomerDetailActivePlan {
  const CustomerDetailActivePlan({
    required this.id,
    required this.planName,
    required this.itemsPerDay,
    required this.pricePerMonth,
    required this.startDate,
    required this.endDate,
    required this.remainingDays,
    this.payLater = false,
    this.creditLimit,
    this.consumptionExposure,
    this.creditHeadroom,
    this.amountDueOnPlan,
    this.totalAmount,
    this.paidAmount,
  });

  final String id;
  final String planName;
  final int itemsPerDay;
  final double pricePerMonth;
  final String startDate;
  final String endDate;
  final int remainingDays;
  final bool payLater;
  final double? creditLimit;
  final double? consumptionExposure;
  final double? creditHeadroom;
  final double? amountDueOnPlan;
  final double? totalAmount;
  final double? paidAmount;

  bool get hasCreditLimit => creditLimit != null;

  factory CustomerDetailActivePlan.fromJson(Map<String, dynamic> json) {
    return CustomerDetailActivePlan(
      id: json['id']?.toString() ?? '',
      planName: json['planName']?.toString() ?? '',
      itemsPerDay: (json['itemsPerDay'] is num)
          ? (json['itemsPerDay'] as num).toInt()
          : 0,
      pricePerMonth: (json['pricePerMonth'] is num)
          ? (json['pricePerMonth'] as num).toDouble()
          : 0,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      remainingDays: (json['remainingDays'] is num)
          ? (json['remainingDays'] as num).toInt()
          : 0,
      payLater: json['payLater'] == true,
      creditLimit: (json['creditLimit'] is num)
          ? (json['creditLimit'] as num).toDouble()
          : null,
      consumptionExposure: (json['consumptionExposure'] is num)
          ? (json['consumptionExposure'] as num).toDouble()
          : null,
      creditHeadroom: (json['creditHeadroom'] is num)
          ? (json['creditHeadroom'] as num).toDouble()
          : null,
      amountDueOnPlan: (json['amountDueOnPlan'] is num)
          ? (json['amountDueOnPlan'] as num).toDouble()
          : null,
      totalAmount: (json['totalAmount'] is num)
          ? (json['totalAmount'] as num).toDouble()
          : null,
      paidAmount: (json['paidAmount'] is num)
          ? (json['paidAmount'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'planName': planName,
    'itemsPerDay': itemsPerDay,
    'pricePerMonth': pricePerMonth,
    'startDate': startDate,
    'endDate': endDate,
    'remainingDays': remainingDays,
    'payLater': payLater,
    if (creditLimit != null) 'creditLimit': creditLimit,
    if (consumptionExposure != null) 'consumptionExposure': consumptionExposure,
    if (creditHeadroom != null) 'creditHeadroom': creditHeadroom,
    if (amountDueOnPlan != null) 'amountDueOnPlan': amountDueOnPlan,
    if (totalAmount != null) 'totalAmount': totalAmount,
    if (paidAmount != null) 'paidAmount': paidAmount,
  };
}

/// Past subscription row.
class CustomerDetailSubscriptionHistoryItem {
  const CustomerDetailSubscriptionHistoryItem({
    required this.planName,
    required this.startDate,
    required this.endDate,
    required this.amountPaid,
    required this.completed,
  });

  final String planName;
  final String startDate;
  final String endDate;
  final double amountPaid;
  final bool completed;

  factory CustomerDetailSubscriptionHistoryItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return CustomerDetailSubscriptionHistoryItem(
      planName: json['planName']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      amountPaid: (json['amountPaid'] is num)
          ? (json['amountPaid'] as num).toDouble()
          : 0,
      completed: json['completed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'planName': planName,
    'startDate': startDate,
    'endDate': endDate,
    'amountPaid': amountPaid,
    'completed': completed,
  };
}

/// Bundle: active plan + history list.
class CustomerDetailSubscriptionsBundle {
  const CustomerDetailSubscriptionsBundle({
    this.activePlan,
    required this.history,
  });

  final CustomerDetailActivePlan? activePlan;
  final List<CustomerDetailSubscriptionHistoryItem> history;

  factory CustomerDetailSubscriptionsBundle.fromJson(
    Map<String, dynamic> json,
  ) {
    CustomerDetailActivePlan? active;
    final ap = json['activePlan'];
    if (ap is Map<String, dynamic>) {
      active = CustomerDetailActivePlan.fromJson(ap);
    }
    final h = <CustomerDetailSubscriptionHistoryItem>[];
    final raw = json['history'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          h.add(CustomerDetailSubscriptionHistoryItem.fromJson(e));
        }
      }
    }
    return CustomerDetailSubscriptionsBundle(activePlan: active, history: h);
  }

  Map<String, dynamic> toJson() => {
    'activePlan': activePlan?.toJson(),
    'history': history.map((e) => e.toJson()).toList(),
  };
}
