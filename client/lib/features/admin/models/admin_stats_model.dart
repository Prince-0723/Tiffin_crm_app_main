class AdminStatsModel {
  const AdminStatsModel({
    this.totalVendors = 0,
    this.totalCustomers = 0,
    this.totalOrders = 0,
    this.totalRevenue = 0,
    this.todayOrders = 0,
    this.todayRevenue = 0,
    this.activeSubscriptions = 0,
    this.pendingOrders = 0,
  });

  final int totalVendors;
  final int totalCustomers;
  final int totalOrders;
  final double totalRevenue;
  final int todayOrders;
  final double todayRevenue;
  final int activeSubscriptions;
  final int pendingOrders;

  static int _int(dynamic v) {
    if (v is num) return v.toInt();
    return 0;
  }

  static double _double(dynamic v) {
    if (v is num) return v.toDouble();
    return 0;
  }

  /// Supports flat keys (legacy) and nested shape from GET /admin/stats.
  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    if (json['vendors'] is Map || json['customers'] is Map) {
      final vendors = json['vendors'];
      final customers = json['customers'];
      final subscriptions = json['subscriptions'];
      final todayOrdersMap = json['todayOrders'];
      final revenue = json['revenue'];
      return AdminStatsModel(
        totalVendors: _int(
          vendors is Map ? vendors['total'] : json['totalVendors'],
        ),
        totalCustomers: _int(
          customers is Map ? customers['total'] : json['totalCustomers'],
        ),
        totalOrders: _int(json['totalOrders']),
        totalRevenue: _double(
          revenue is Map ? revenue['last30Days'] : json['totalRevenue'],
        ),
        todayOrders: _int(
          todayOrdersMap is Map ? todayOrdersMap['total'] : json['todayOrders'],
        ),
        todayRevenue: _double(
          revenue is Map ? revenue['today'] : json['todayRevenue'],
        ),
        activeSubscriptions: _int(
          subscriptions is Map
              ? subscriptions['active']
              : json['activeSubscriptions'],
        ),
        pendingOrders: _int(
          todayOrdersMap is Map ? todayOrdersMap['pending'] : json['pendingOrders'],
        ),
      );
    }

    return AdminStatsModel(
      totalVendors: _int(json['totalVendors']),
      totalCustomers: _int(json['totalCustomers']),
      totalOrders: _int(json['totalOrders']),
      totalRevenue: _double(json['totalRevenue']),
      todayOrders: _int(json['todayOrders']),
      todayRevenue: _double(json['todayRevenue']),
      activeSubscriptions: _int(json['activeSubscriptions']),
      pendingOrders: _int(json['pendingOrders']),
    );
  }
}
