class PlanModel {
  const PlanModel({
    required this.id,
    required this.planName,
    required this.price,
    required this.planType,
    this.color,
    this.mealSlots = const [],
    this.customerId,
    this.isActive = true,
    this.vendorId,
  });

  final String id;
  final String planName;
  final double price;
  final String planType;
  final String? color;
  final List<MealSlotModel> mealSlots;
  final String? customerId;
  final bool isActive;
  final String? vendorId;

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    List<MealSlotModel> slots = [];
    if (json['mealSlots'] is List) {
      for (final e in json['mealSlots'] as List) {
        if (e is Map) {
          slots.add(
            MealSlotModel.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return PlanModel(
      id: id,
      planName: json['planName']?.toString() ?? '',
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0,
      planType: json['planType']?.toString() ?? 'monthly',
      color: json['color']?.toString(),
      mealSlots: slots,
      customerId: json['customerId']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
      vendorId: json['vendorId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planName': planName,
      'price': price,
      'planType': planType,
      if (color != null) 'color': color,
      'mealSlots': mealSlots.map((e) => e.toJson()).toList(),
      if (customerId != null) 'customerId': customerId,
      'isActive': isActive,
    };
  }
}

class MealSlotModel {
  const MealSlotModel({
    required this.slot,
    this.items = const [],
  });

  final String slot;
  final List<MealSlotItemModel> items;

  factory MealSlotModel.fromJson(Map<String, dynamic> json) {
    List<MealSlotItemModel> itemList = [];
    if (json['items'] is List) {
      for (final e in json['items'] as List) {
        if (e is Map) {
          itemList.add(
            MealSlotItemModel.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return MealSlotModel(
      slot: json['slot']?.toString() ?? 'lunch',
      items: itemList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slot': slot,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

class MealSlotItemModel {
  const MealSlotItemModel({
    required this.itemId,
    this.itemName,
    this.quantity = 1,
    this.unitPrice,
  });

  final String itemId;
  final String? itemName;
  final int quantity;
  final double? unitPrice;

  factory MealSlotItemModel.fromJson(Map<String, dynamic> json) {
    // API often returns populated `itemId` as a full Item object, not a string.
    final dynamic itemIdRaw = json['itemId'] ?? json['item'];
    String itemId = '';
    String? itemName = json['itemName']?.toString();
    double? unitPrice = (json['unitPrice'] is num)
        ? (json['unitPrice'] as num).toDouble()
        : null;

    if (itemIdRaw is Map) {
      final m = Map<String, dynamic>.from(itemIdRaw);
      itemId = m['_id']?.toString() ?? m['id']?.toString() ?? '';
      itemName ??= m['name']?.toString();
      if (unitPrice == null && m['unitPrice'] is num) {
        unitPrice = (m['unitPrice'] as num).toDouble();
      }
    } else {
      itemId = itemIdRaw?.toString() ?? '';
    }

    return MealSlotItemModel(
      itemId: itemId,
      itemName: itemName,
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1,
      unitPrice: unitPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'quantity': quantity,
    };
  }
}
