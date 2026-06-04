class ZoneModel {
  final String id;
  final String name;
  final String description;
  final String color;
  final bool isActive;

  ZoneModel({
    required this.id,
    required this.name,
    this.description = '',
    this.color = '',
    this.isActive = true,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      isActive: json['isActive'] == null ? true : json['isActive'] == true,
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (description.isNotEmpty) 'description': description,
        if (color.isNotEmpty) 'color': color,
        'isActive': isActive,
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'description': description,
        'color': color,
        'isActive': isActive,
      };
}

