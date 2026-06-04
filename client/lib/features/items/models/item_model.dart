class ItemModel {
  const ItemModel({
    required this.id,
    required this.name,
    this.unitPrice,
    required this.unit,
    required this.category,
    this.isActive = true,
    this.vendorId,
  });

  final String id;
  final String name;
  /// Omitted when the vendor adds an item without a catalog price (treated as 0 for billing sums).
  final double? unitPrice;
  final String unit;
  final String category;
  final bool isActive;
  final String? vendorId;

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    return ItemModel(
      id: id,
      name: json['name']?.toString() ?? '',
      unitPrice:
          json['unitPrice'] is num ? (json['unitPrice'] as num).toDouble() : null,
      unit: json['unit']?.toString() ?? 'piece',
      category: json['category']?.toString() ?? 'other',
      isActive: json['isActive'] as bool? ?? true,
      vendorId: json['vendorId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'unitPrice': unitPrice,
      'unit': unit,
      'category': category,
      'isActive': isActive,
    };
  }
}
