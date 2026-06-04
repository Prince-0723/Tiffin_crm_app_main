class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.customerId,
    required this.planId,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.deliverySlot,
    this.deliveryDays,
    this.pausedFrom,
    this.pausedUntil,
    this.autoRenew = false,
    this.notes,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.planName,
    this.planType,
    this.planPrice,
    this.totalAmount,
    this.paidAmount,
    this.remainingBalance,
    this.payLater,
    this.creditLimit,
    this.paymentDueDate,
    this.consumptionExposure,
    this.creditHeadroom,
  });

  final String id;
  final String customerId;
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? deliverySlot;
  final List<int>? deliveryDays;
  final DateTime? pausedFrom;
  final DateTime? pausedUntil;
  final bool autoRenew;
  final String? notes;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? planName;
  final String? planType;
  final double? planPrice;
  final double? totalAmount;
  final double? paidAmount;
  final double? remainingBalance;
  final bool? payLater;
  final double? creditLimit;
  final DateTime? paymentDueDate;
  /// Served meal value not yet covered by [paidAmount] (pay-later exposure).
  final double? consumptionExposure;
  /// Rupees left under the credit cap before new meals are blocked; null if unlimited.
  final double? creditHeadroom;

  /// Cash still owed on the plan contract when [payLater] is true.
  double get amountDueOnPlan {
    if (payLater != true) return 0;
    final t = totalAmount ?? 0;
    final p = paidAmount ?? 0;
    final d = t - p;
    return d > 0 ? d : 0;
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';

    // Handle customerId as either object or plain string
    String customerId = '';
    String? customerName;
    String? customerPhone;
    String? customerAddress;
    final rawCustomer = json['customerId'];
    if (rawCustomer is Map<String, dynamic>) {
      customerId = rawCustomer['_id']?.toString() ?? '';
      customerName = rawCustomer['name']?.toString();
      customerPhone = rawCustomer['phone']?.toString();
      customerAddress = rawCustomer['address']?.toString();
    } else {
      customerId = rawCustomer?.toString() ?? '';
    }

    // Handle planId as either object or plain string
    String planId = '';
    String? planName;
    String? planType;
    double? planPrice;
    final rawPlan = json['planId'];
    if (rawPlan is Map<String, dynamic>) {
      planId = rawPlan['_id']?.toString() ?? '';
      planName = rawPlan['planName']?.toString();
      planType = rawPlan['planType']?.toString();
      planPrice = (rawPlan['price'] as num?)?.toDouble();
    } else {
      planId = rawPlan?.toString() ?? '';
    }

    DateTime? start;
    if (json['startDate'] is String) {
      start = DateTime.tryParse(json['startDate'] as String);
    }

    DateTime? end;
    if (json['endDate'] is String) {
      end = DateTime.tryParse(json['endDate'] as String);
    }

    DateTime? pf;
    if (json['pausedFrom'] is String) {
      pf = DateTime.tryParse(json['pausedFrom'] as String);
    }

    DateTime? pu;
    if (json['pausedUntil'] is String) {
      pu = DateTime.tryParse(json['pausedUntil'] as String);
    }

    DateTime? pDue;
    if (json['paymentDueDate'] is String &&
        (json['paymentDueDate'] as String).isNotEmpty) {
      pDue = DateTime.tryParse(json['paymentDueDate'] as String);
    }

    List<int>? days;
    if (json['deliveryDays'] is List) {
      days = (json['deliveryDays'] as List)
          .map((e) => (e is num) ? e.toInt() : 0)
          .toList();
    }

    return SubscriptionModel(
      id: id,
      customerId: customerId,
      planId: planId,
      startDate: start ?? DateTime.now(),
      endDate: end ?? DateTime.now(),
      status: json['status']?.toString() ?? 'active',
      deliverySlot: json['deliverySlot']?.toString(),
      deliveryDays: days,
      pausedFrom: pf,
      pausedUntil: pu,
      autoRenew: json['autoRenew'] as bool? ?? false,
      notes: json['notes']?.toString(),
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      planName: planName,
      planType: planType,
      planPrice: planPrice,
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      paidAmount: (json['paidAmount'] as num?)?.toDouble(),
      remainingBalance: (json['remainingBalance'] as num?)?.toDouble(),
      payLater: json['payLater'] as bool?,
      creditLimit: (json['creditLimit'] as num?)?.toDouble(),
      paymentDueDate: pDue,
      consumptionExposure: (json['consumptionExposure'] as num?)?.toDouble(),
      creditHeadroom: (json['creditHeadroom'] as num?)?.toDouble(),
    );
  }
}
