class DeliveryStaffModel {
  const DeliveryStaffModel({
    required this.id,
    required this.name,
    required this.phone,
    this.areas = const [],
    this.isActive = true,
    this.location,
    this.joiningDate,
    this.vendorId,
  });

  final String id;
  final String name;
  final String phone;
  final List<String> areas;
  final bool isActive;
  final StaffLocation? location;
  final DateTime? joiningDate;
  final String? vendorId;

  factory DeliveryStaffModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    List<String> areasList = [];
    if (json['areas'] is List) {
      areasList = (json['areas'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    StaffLocation? loc;
    if (json['location'] is Map<String, dynamic>) {
      final l = json['location'] as Map<String, dynamic>;
      final coords = l['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lng = (coords[0] is num) ? (coords[0] as num).toDouble() : null;
        final lat = (coords[1] is num) ? (coords[1] as num).toDouble() : null;
        if (lng != null && lat != null) loc = StaffLocation(lat: lat, lng: lng);
      }
    }
    DateTime? joining;
    if (json['joiningDate'] != null && json['joiningDate'] is String) {
      joining = DateTime.tryParse(json['joiningDate'] as String);
    }
    return DeliveryStaffModel(
      id: id,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      areas: areasList,
      isActive: json['isActive'] as bool? ?? true,
      location: loc,
      joiningDate: joining,
      vendorId: json['vendorId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'areas': areas,
      'isActive': isActive,
      if (joiningDate != null) 'joiningDate': (joiningDate!).toIso8601String(),
    };
  }
}

class StaffLocation {
  const StaffLocation({required this.lat, required this.lng});
  final double lat;
  final double lng;
}
