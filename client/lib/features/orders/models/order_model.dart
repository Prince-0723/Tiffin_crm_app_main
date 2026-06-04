String _normalizeOrderStatus(String raw) {
  final s = raw.toLowerCase().trim();
  if (s == 'cooking') return 'processing';
  return s;
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.customerId,
    required this.date,
    required this.status,
    this.mealTime,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.planId,
    this.deliveryStaffId,
    this.deliveryStaffName,
    this.deliveryStaffPhone,
    this.mealSlots,
    this.totalAmount,
    this.slot,
    this.customerLocation,
  });

  final String id;
  final String customerId;
  final DateTime date;
  final String status;
  /// Meal time tag used by Daily Orders screen: breakfast | lunch | dinner.
  /// Optional to keep backward compatibility with older API payloads.
  final String? mealTime;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? planId;
  final String? deliveryStaffId;
  final String? deliveryStaffName;
  final String? deliveryStaffPhone;
  final List<dynamic>? mealSlots;
  final double? totalAmount;
  final String? slot;
  final OrderLocation? customerLocation;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    DateTime orderDate = DateTime.now();
    final rawDate = json['orderDate'] ?? json['date'];
    if (rawDate != null) {
      if (rawDate is String) {
        orderDate = DateTime.tryParse(rawDate) ?? orderDate;
      }
    }
    OrderLocation? loc;
    if (json['customerId'] is Map) {
      final c = json['customerId'] as Map<String, dynamic>;
      if (c['location'] is Map) {
        final l = c['location'] as Map;
        final coords = l['coordinates'];
        if (coords is List && coords.length >= 2) {
          final lng = (coords[0] is num) ? (coords[0] as num).toDouble() : null;
          final lat = (coords[1] is num) ? (coords[1] as num).toDouble() : null;
          if (lng != null && lat != null) loc = OrderLocation(lat: lat, lng: lng);
        }
      }
    }
    return OrderModel(
      id: id,
      customerId: json['customerId'] is String
          ? json['customerId'] as String
          : (json['customerId'] as Map?)?['_id']?.toString() ?? '',
      date: orderDate,
      status: _normalizeOrderStatus(json['status']?.toString() ?? 'pending'),
      mealTime: (json['mealTime'] ??
              json['mealType'] ??
              json['mealPeriod'] ??
              json['meal_type'] ??
              json['meal_time'])
          ?.toString(),
      customerName: json['customerName']?.toString() ??
          (json['customerId'] is Map
              ? (json['customerId'] as Map)['name']?.toString()
              : null),
      customerPhone: json['customerPhone']?.toString() ??
          (json['customerId'] is Map
              ? (json['customerId'] as Map)['phone']?.toString()
              : null),
      customerAddress: json['customerAddress']?.toString() ??
          (json['customerId'] is Map
              ? (json['customerId'] as Map)['address']?.toString()
              : null),
      planId: json['planId']?.toString(),
      deliveryStaffId: json['deliveryStaffId']?.toString(),
      deliveryStaffName: json['deliveryStaffName']?.toString() ??
          (json['deliveryStaffId'] is Map
              ? (json['deliveryStaffId'] as Map)['name']?.toString()
              : null),
      deliveryStaffPhone: json['deliveryStaffPhone']?.toString() ??
          (json['deliveryStaffId'] is Map
              ? (json['deliveryStaffId'] as Map)['phone']?.toString()
              : null),
      mealSlots: json['resolvedItems'] is List
          ? json['resolvedItems'] as List
          : (json['mealSlots'] is List ? json['mealSlots'] as List : null),
      totalAmount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : (json['totalAmount'] is num
              ? (json['totalAmount'] as num).toDouble()
              : null),
      slot: (json['deliverySlot'] ?? json['slot'])?.toString(),
      customerLocation: loc,
    );
  }
}

class OrderLocation {
  const OrderLocation({required this.lat, required this.lng});
  final double lat;
  final double lng;
}
