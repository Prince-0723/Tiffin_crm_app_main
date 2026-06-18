import 'dart:math' as math;

/// Vendor fields exposed to customers (e.g. UPI for payments).
class CustomerVendorInfo {
  const CustomerVendorInfo({
    this.businessName,
    this.ownerName,
    this.phone,
    this.upiId,
    this.announcementText,
    this.announcementUpdatedAt,
  });

  final String? businessName;
  final String? ownerName;
  final String? phone;
  final String? upiId;

  /// Current portal announcement from vendor (GET /customer/me → vendor.announcement).
  final String? announcementText;
  final DateTime? announcementUpdatedAt;

  factory CustomerVendorInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomerVendorInfo();
    String? annText;
    DateTime? annAt;
    final rawAnn = json['announcement'];
    if (rawAnn is Map<String, dynamic>) {
      annText = rawAnn['text']?.toString();
      final u = rawAnn['updatedAt'];
      if (u is String) annAt = DateTime.tryParse(u);
    }
    return CustomerVendorInfo(
      businessName: json['businessName']?.toString(),
      ownerName: json['ownerName']?.toString(),
      phone: json['phone']?.toString(),
      upiId: json['upiId']?.toString(),
      announcementText: annText,
      announcementUpdatedAt: annAt,
    );
  }
}

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.status = 'active',
    this.dietType,
    this.timeSlots,
    this.tiffinCount,
    this.hasInactiveMeals,
    this.hasCustomizedMeals,
    this.whatsapp,
    this.area,
    this.landmark,
    this.notes,
    this.tags,
    this.balance,
    this.walletBalance,
    this.creditLimit,
    this.location,
    this.zoneName,
    this.zone,
    this.vendorId,
    this.ownerId,
    this.vendor,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String status;

  /// Optional diet type hint used by list filters: veg | non_veg | mixed.
  final String? dietType;

  /// Optional time slots associated with customer (from meal plans/subscription), e.g. morning/afternoon/evening or breakfast/lunch/dinner.
  final List<String>? timeSlots;

  /// Optional aggregate tiffin count, if backend provides it.
  final int? tiffinCount;

  /// Optional: whether customer currently has inactive meals in plan.
  final bool? hasInactiveMeals;

  /// Optional: whether customer currently uses customized meals.
  final bool? hasCustomizedMeals;
  final String? whatsapp;
  final String? area;
  final String? landmark;
  final String? notes;
  final List<String>? tags;
  final double? balance;
  final double? walletBalance;
  final double? creditLimit;
  final GeoPoint? location;

  /// Resolved from [zoneId] when API includes it (GET /customers/:id).
  final String? zoneName;

  /// Free-text zone / area label saved from add-customer form.
  final String? zone;
  final String? vendorId;

  /// Vendor (User) id — used for public portal announcement API.
  final String? ownerId;
  final CustomerVendorInfo? vendor;
  final DateTime? createdAt;

  String get fullName => name;

  /// Spendable wallet: max of canonical + legacy fields (migration drift), floored at 0.
  double get effectiveWalletBalance =>
      math.max(0, math.max(walletBalance ?? 0, balance ?? 0));

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    List<String>? tags;
    if (json['tags'] != null) {
      if (json['tags'] is List) {
        tags = (json['tags'] as List)
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }

    List<String>? timeSlots;
    dynamic rawSlots =
        json['timeSlots'] ??
        json['time_slots'] ??
        json['slots'] ??
        json['mealSlots'] ??
        json['meal_slots'] ??
        json['deliverySlots'] ??
        json['delivery_slots'] ??
        json['deliverySlot'] ??
        json['delivery_slot'];
    if (rawSlots is String) {
      final s = rawSlots.trim();
      if (s.isNotEmpty) timeSlots = [s];
    } else if (rawSlots is List) {
      final list = rawSlots
          .map((e) => e?.toString() ?? '')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (list.isNotEmpty) timeSlots = list;
    }

    final dietType = (json['dietType'] ?? json['diet_type'] ?? json['diet'])
        ?.toString();
    final tiffinCount =
        (json['tiffinCount'] ??
        json['tiffin_count'] ??
        json['tiffinCounts'] ??
        json['tiffin_counts']);
    final hasInactiveMeals =
        json['hasInactiveMeals'] ??
        json['inactiveMeals'] ??
        json['inactive_meals'];
    final hasCustomizedMeals =
        json['hasCustomizedMeals'] ??
        json['customizedMeals'] ??
        json['customized_meals'];
    GeoPoint? location;
    if (json['location'] is Map<String, dynamic>) {
      final loc = json['location'] as Map<String, dynamic>;
      final coords = loc['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lng = (coords[0] is num) ? (coords[0] as num).toDouble() : null;
        final lat = (coords[1] is num) ? (coords[1] as num).toDouble() : null;
        if (lng != null && lat != null) location = GeoPoint(lat: lat, lng: lng);
      }
    }
    DateTime? createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is String) {
        createdAt = DateTime.tryParse(json['createdAt'] as String);
      }
    }
    return CustomerModel(
      id: id,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      status: json['status']?.toString() ?? 'active',
      dietType: dietType,
      timeSlots: timeSlots,
      tiffinCount: (tiffinCount is num)
          ? tiffinCount.toInt()
          : int.tryParse('$tiffinCount'),
      hasInactiveMeals: (hasInactiveMeals is bool) ? hasInactiveMeals : null,
      hasCustomizedMeals: (hasCustomizedMeals is bool)
          ? hasCustomizedMeals
          : null,
      whatsapp: json['whatsapp']?.toString(),
      area: json['area']?.toString(),
      landmark: json['landmark']?.toString(),
      notes: json['notes']?.toString(),
      tags: tags,
      balance: (json['balance'] is num)
          ? (json['balance'] as num).toDouble()
          : null,
      walletBalance: (json['walletBalance'] is num)
          ? (json['walletBalance'] as num).toDouble()
          : null,
      creditLimit: (json['creditLimit'] is num)
          ? (json['creditLimit'] as num).toDouble()
          : null,
      location: location,
      zoneName: json['zoneName']?.toString(),
      zone: json['zone']?.toString(),
      vendorId: json['vendorId']?.toString(),
      ownerId: json['ownerId']?.toString(),
      vendor: json['vendor'] is Map<String, dynamic>
          ? CustomerVendorInfo.fromJson(json['vendor'] as Map<String, dynamic>)
          : null,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      'status': status,
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (area != null) 'area': area,
      if (zone != null && zone!.trim().isNotEmpty) 'zone': zone!.trim(),
      if (landmark != null) 'landmark': landmark,
      if (notes != null) 'notes': notes,
      if (tags != null && tags!.isNotEmpty) 'tags': tags,
      if (creditLimit != null) 'creditLimit': creditLimit,
      if (location != null)
        'location': {
          'type': 'Point',
          'coordinates': [location!.lng, location!.lat],
        },
    };
  }
}

class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

class CustomerBalanceModel {
  const CustomerBalanceModel({
    required this.walletBalance,
    required this.subscriptionBalance,
  });

  final double walletBalance;
  final double subscriptionBalance;

  factory CustomerBalanceModel.fromJson(Map<String, dynamic> json) {
    return CustomerBalanceModel(
      walletBalance: (json['walletBalance'] is num)
          ? (json['walletBalance'] as num).toDouble()
          : 0,
      subscriptionBalance: (json['subscriptionBalance'] is num)
          ? (json['subscriptionBalance'] as num).toDouble()
          : 0,
    );
  }
}
