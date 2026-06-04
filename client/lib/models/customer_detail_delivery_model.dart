/// One row in the subscription deliveries list.
class CustomerDetailDeliveryRow {
  const CustomerDetailDeliveryRow({
    required this.date,
    required this.items,
    required this.status,
    this.amount = 0,
  });

  final String date;
  final String items;
  final String status;
  /// Billed meal total for this calendar day (`plan.price` / slot totals), not catalog items.
  final double amount;

  factory CustomerDetailDeliveryRow.fromJson(Map<String, dynamic> json) {
    return CustomerDetailDeliveryRow(
      date: json['date']?.toString() ?? '',
      items: json['items']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      amount:
          json['amount'] is num ? (json['amount'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'items': items,
        'status': status,
        'amount': amount,
      };
}

/// Active subscription summary for the deliveries tab header.
class CustomerDetailDeliveriesSubscriptionInfo {
  const CustomerDetailDeliveriesSubscriptionInfo({
    required this.planName,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.remainingDays,
  });

  final String planName;
  final String startDate;
  final String endDate;
  final int totalDays;
  final int remainingDays;

  factory CustomerDetailDeliveriesSubscriptionInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    return CustomerDetailDeliveriesSubscriptionInfo(
      planName: json['planName']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      totalDays: (json['totalDays'] is num)
          ? (json['totalDays'] as num).toInt()
          : 0,
      remainingDays: (json['remainingDays'] is num)
          ? (json['remainingDays'] as num).toInt()
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'planName': planName,
        'startDate': startDate,
        'endDate': endDate,
        'totalDays': totalDays,
        'remainingDays': remainingDays,
      };
}

/// GET /customer-details/:id/deliveries payload: subscription + all days.
class CustomerDetailDeliveriesBundle {
  const CustomerDetailDeliveriesBundle({
    this.subscription,
    required this.deliveries,
  });

  final CustomerDetailDeliveriesSubscriptionInfo? subscription;
  final List<CustomerDetailDeliveryRow> deliveries;

  factory CustomerDetailDeliveriesBundle.fromJson(Map<String, dynamic> json) {
    CustomerDetailDeliveriesSubscriptionInfo? sub;
    final rawSub = json['subscription'];
    if (rawSub is Map<String, dynamic>) {
      sub = CustomerDetailDeliveriesSubscriptionInfo.fromJson(rawSub);
    }
    final rawList = json['deliveries'];
    final deliveries = <CustomerDetailDeliveryRow>[];
    if (rawList is List) {
      for (final e in rawList) {
        if (e is Map<String, dynamic>) {
          deliveries.add(CustomerDetailDeliveryRow.fromJson(e));
        }
      }
    }
    return CustomerDetailDeliveriesBundle(
      subscription: sub,
      deliveries: deliveries,
    );
  }

  Map<String, dynamic> toJson() => {
        'subscription': subscription?.toJson(),
        'deliveries': deliveries.map((e) => e.toJson()).toList(),
      };
}
