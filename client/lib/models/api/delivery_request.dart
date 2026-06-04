// API_INTEGRATION
// Endpoint: GET /api/delivery
// Purpose: Get daily delivery list
// Request: (query: date)
// Response: { deliveries: List<DeliveryModel> }

// API_INTEGRATION
// Endpoint: PUT /api/delivery/:id/status
// Purpose: Update delivery status
// Request: { status: String, deliveryTime?: String }
// Response: { id: String, status: String }

class DeliveryStatusUpdateRequest {
  const DeliveryStatusUpdateRequest({
    required this.status,
    this.deliveryTime,
  });
  final String status;
  final String? deliveryTime;
}
