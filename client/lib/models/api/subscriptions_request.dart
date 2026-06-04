// API_INTEGRATION
// Endpoint: GET /api/subscriptions
// Purpose: Fetch subscriptions (optional filter by customerId)
// Request: (query optional: customerId, status)
// Response: { subscriptions: List<SubscriptionModel> }

// API_INTEGRATION
// Endpoint: POST /api/subscriptions
// Purpose: Create subscription
// Request: { customerId: String, planId: String, startDate: String, endDate: String, autoRenewal?: bool }
// Response: { id: String, customerId: String, planId: String, status: String }

class SubscriptionCreateRequest {
  const SubscriptionCreateRequest({
    required this.customerId,
    required this.planId,
    required this.startDate,
    required this.endDate,
    this.autoRenewal = false,
  });
  final String customerId;
  final String planId;
  final String startDate;
  final String endDate;
  final bool autoRenewal;
}

class SubscriptionCreateResponse {
  const SubscriptionCreateResponse({
    required this.id,
    required this.customerId,
    required this.planId,
    required this.status,
  });
  final String id;
  final String customerId;
  final String planId;
  final String status;
}
