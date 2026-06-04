class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    this.paymentDate,
    this.transactionRef,
    this.status = 'completed',
    this.customerName,
  });

  final String id;
  final String customerId;
  final double amount;
  final String paymentMethod;
  final DateTime? paymentDate;
  final String? transactionRef;
  final String status;
  final String? customerName;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    DateTime? pd;
    final rawPd = json['paymentDate'];
    if (rawPd != null) {
      if (rawPd is String) {
        pd = DateTime.tryParse(rawPd);
      } else if (rawPd is num) {
        var ms = rawPd.toInt();
        // Heuristic: Unix seconds vs milliseconds.
        if (ms > 0 && ms < 100000000000) ms *= 1000;
        pd = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    return PaymentModel(
      id: id,
      customerId: json['customerId'] is String
          ? json['customerId'] as String
          : (json['customerId'] as Map?)?['_id']?.toString() ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      paymentDate: pd,
      transactionRef: json['transactionRef']?.toString(),
      status: json['status']?.toString() ?? 'completed',
      customerName: json['customerId'] is Map
          ? (json['customerId'] as Map)['name']?.toString()
          : null,
    );
  }
}
