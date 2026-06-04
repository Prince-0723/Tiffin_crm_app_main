class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    required this.mode,
    required this.status,
  });

  final String id;
  final String customerId;
  final double amount;
  final DateTime date;
  final String mode;
  final String status;
}
