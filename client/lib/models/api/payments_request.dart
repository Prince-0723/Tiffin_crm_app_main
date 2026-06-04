// API_INTEGRATION
// Endpoint: POST /api/payments
// Purpose: Record payment
// Request: { customerId: String, amount: double, mode: String }
// Response: { id: String, customerId: String, amount: double, date: String }

class PaymentCreateRequest {
  const PaymentCreateRequest({
    required this.customerId,
    required this.amount,
    required this.mode,
  });
  final String customerId;
  final double amount;
  final String mode;
}

class PaymentCreateResponse {
  const PaymentCreateResponse({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.date,
  });
  final String id;
  final String customerId;
  final double amount;
  final String date;
}

// API_INTEGRATION
// Endpoint: GET /api/payments
// Purpose: Get payment history (optional filter by customerId)
// Request: (query optional: customerId)
// Response: { payments: List<PaymentModel> }
