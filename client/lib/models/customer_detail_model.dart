import 'dart:math' as math;

/// Wallet + subscription balances for the Balance tab.
class CustomerDetailBalance {
  const CustomerDetailBalance({
    required this.walletBalance,
    required this.subscriptionBalance,
  });

  final double walletBalance;
  final double subscriptionBalance;

  factory CustomerDetailBalance.fromJson(Map<String, dynamic> json) {
    final raw = (json['walletBalance'] is num)
        ? (json['walletBalance'] as num).toDouble()
        : 0.0;
    return CustomerDetailBalance(
      walletBalance: math.max(0, raw),
      subscriptionBalance: (json['subscriptionBalance'] is num)
          ? (json['subscriptionBalance'] as num).toDouble()
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'walletBalance': walletBalance,
    'subscriptionBalance': subscriptionBalance,
  };
}

/// API DTO for GET /customer-details/:id/info (customer profile summary).
class CustomerDetailInfo {
  const CustomerDetailInfo({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.planName,
    required this.startDate,
    required this.status,
    this.zoneName,
    this.sharedLocationLat,
    this.sharedLocationLng,
    this.activeSubscriptionId,
    this.payLater = false,
    this.creditLimit,
    this.consumptionExposure,
    this.creditHeadroom,
    this.amountDueOnPlan,
    this.subscriptionBalance,
    this.totalAmount,
    this.paidAmount,
  });

  final String name;
  final String phone;
  final String email;
  final String address;
  final String planName;
  final String startDate;
  final String status;

  /// Delivery zone label from [Customer.zoneId].
  final String? zoneName;

  /// GPS from customer portal "Share location" ([lng, lat] GeoJSON on server).
  final double? sharedLocationLat;
  final double? sharedLocationLng;
  final String? activeSubscriptionId;
  final bool payLater;
  final double? creditLimit;
  final double? consumptionExposure;
  final double? creditHeadroom;
  final double? amountDueOnPlan;
  final double? subscriptionBalance;
  final double? totalAmount;
  final double? paidAmount;

  bool get hasCreditLimit => creditLimit != null;

  bool get hasSharedMapLocation =>
      sharedLocationLat != null &&
      sharedLocationLng != null &&
      (sharedLocationLat != 0 || sharedLocationLng != 0);

  /// Parses JSON from API `data` payload.
  factory CustomerDetailInfo.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;
    if (json['location'] is Map<String, dynamic>) {
      final loc = json['location'] as Map<String, dynamic>;
      final c = loc['coordinates'];
      if (c is List && c.length >= 2) {
        final rawLng = (c[0] is num) ? (c[0] as num).toDouble() : null;
        final rawLat = (c[1] is num) ? (c[1] as num).toDouble() : null;
        if (rawLng != null && rawLat != null && (rawLat != 0 || rawLng != 0)) {
          lat = rawLat;
          lng = rawLng;
        }
      }
    }
    return CustomerDetailInfo(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      planName: json['planName']?.toString() ?? '',
      startDate: json['startDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      zoneName: json['zoneName']?.toString(),
      sharedLocationLat: lat,
      sharedLocationLng: lng,
      activeSubscriptionId: json['activeSubscriptionId']?.toString(),
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
      subscriptionBalance: (json['subscriptionBalance'] is num)
          ? (json['subscriptionBalance'] as num).toDouble()
          : null,
      totalAmount: (json['totalAmount'] is num)
          ? (json['totalAmount'] as num).toDouble()
          : null,
      paidAmount: (json['paidAmount'] is num)
          ? (json['paidAmount'] as num).toDouble()
          : null,
    );
  }

  /// Serializes for caching or debug.
  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'planName': planName,
    'startDate': startDate,
    'status': status,
    if (zoneName != null && zoneName!.trim().isNotEmpty) 'zoneName': zoneName,
    if (activeSubscriptionId != null)
      'activeSubscriptionId': activeSubscriptionId,
    'payLater': payLater,
    if (creditLimit != null) 'creditLimit': creditLimit,
    if (consumptionExposure != null) 'consumptionExposure': consumptionExposure,
    if (creditHeadroom != null) 'creditHeadroom': creditHeadroom,
    if (amountDueOnPlan != null) 'amountDueOnPlan': amountDueOnPlan,
    if (subscriptionBalance != null) 'subscriptionBalance': subscriptionBalance,
    if (totalAmount != null) 'totalAmount': totalAmount,
    if (paidAmount != null) 'paidAmount': paidAmount,
    if (hasSharedMapLocation)
      'location': {
        'type': 'Point',
        'coordinates': [sharedLocationLng!, sharedLocationLat!],
      },
  };
}

/// Receipt payload for bottom sheet / share.
class CustomerDetailReceipt {
  const CustomerDetailReceipt({
    required this.businessName,
    required this.date,
    required this.description,
    required this.items,
    required this.total,
    required this.paymentMode,
    required this.type,
  });

  final String businessName;
  final String date;
  final String description;
  final List<CustomerDetailReceiptLine> items;
  final double total;
  final String paymentMode;
  final String type;

  factory CustomerDetailReceipt.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final lines = <CustomerDetailReceiptLine>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          lines.add(CustomerDetailReceiptLine.fromJson(e));
        }
      }
    }
    return CustomerDetailReceipt(
      businessName: json['businessName']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      items: lines,
      total: (json['total'] is num) ? (json['total'] as num).toDouble() : 0,
      paymentMode: json['paymentMode']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'businessName': businessName,
    'date': date,
    'description': description,
    'items': items.map((e) => e.toJson()).toList(),
    'total': total,
    'paymentMode': paymentMode,
    'type': type,
  };
}

class CustomerDetailReceiptLine {
  const CustomerDetailReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final double quantity;
  final double unitPrice;

  factory CustomerDetailReceiptLine.fromJson(Map<String, dynamic> json) {
    return CustomerDetailReceiptLine(
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toDouble()
          : 1,
      unitPrice: (json['unitPrice'] is num)
          ? (json['unitPrice'] as num).toDouble()
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };
}
