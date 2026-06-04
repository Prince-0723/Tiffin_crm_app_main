// API_INTEGRATION
// Endpoint: GET /api/reports/daily
// Purpose: Get daily revenue report
// Request: (query optional: date)
// Response: { revenue: double, orders: int, ... }

class ReportDailyResponse {
  const ReportDailyResponse({
    required this.revenue,
    required this.orders,
  });
  final double revenue;
  final int orders;
}

// API_INTEGRATION
// Endpoint: GET /api/reports/weekly
// Purpose: Get weekly report
// Response: { revenue: double, ... }

// API_INTEGRATION
// Endpoint: GET /api/reports/monthly
// Purpose: Get monthly report
// Response: { revenue: double, ... }
