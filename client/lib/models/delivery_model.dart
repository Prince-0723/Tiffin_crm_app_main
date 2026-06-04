class DeliveryModel {
  const DeliveryModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.address,
    required this.date,
    required this.status,
    this.deliveryTime,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String address;
  final DateTime date;
  final String status;
  final String? deliveryTime;
}
