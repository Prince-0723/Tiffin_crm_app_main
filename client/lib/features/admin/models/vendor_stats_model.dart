class VendorStatsModel {
  const VendorStatsModel({
    required this.vendorId,
    required this.vendorName,
    required this.totalCustomers,
    required this.activeCustomers,
    required this.pausedCustomers,
    required this.expiredCustomers,
  });

  final String vendorId;
  final String vendorName;
  final int totalCustomers;
  final int activeCustomers;
  final int pausedCustomers;
  final int expiredCustomers;

  factory VendorStatsModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> m = json;
    int n(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return VendorStatsModel(
      vendorId: m['vendorId']?.toString() ?? '',
      vendorName: m['vendorName']?.toString() ?? '—',
      totalCustomers: n(m['totalCustomers']),
      activeCustomers: n(m['activeCustomers']),
      pausedCustomers: n(m['pausedCustomers']),
      expiredCustomers: n(m['expiredCustomers']),
    );
  }
}
