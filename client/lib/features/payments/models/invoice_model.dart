class InvoiceModel {
  const InvoiceModel({
    required this.id,
    required this.customerId,
    this.billingStart,
    this.billingEnd,
    this.amount = 0,
    this.status = 'unpaid',
    this.dueDate,
    this.shareToken,
    this.customerName,
  });

  final String id;
  final String customerId;
  final DateTime? billingStart;
  final DateTime? billingEnd;
  final double amount;
  final String status;
  final DateTime? dueDate;
  final String? shareToken;
  final String? customerName;

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    DateTime? start;
    if (json['billingStart'] != null && json['billingStart'] is String) {
      start = DateTime.tryParse(json['billingStart'] as String);
    }
    DateTime? end;
    if (json['billingEnd'] != null && json['billingEnd'] is String) {
      end = DateTime.tryParse(json['billingEnd'] as String);
    }
    DateTime? due;
    if (json['dueDate'] != null && json['dueDate'] is String) {
      due = DateTime.tryParse(json['dueDate'] as String);
    }
    final isVoid = json['isVoid'] == true;
    final resolvedStatus = isVoid
        ? 'voided'
        : (json['paymentStatus']?.toString() ??
              json['status']?.toString() ??
              'unpaid');
    final double resolvedAmount = (json['netAmount'] is num)
        ? (json['netAmount'] as num).toDouble()
        : (json['amount'] is num)
            ? (json['amount'] as num).toDouble()
            : 0.0;

    return InvoiceModel(
      id: id,
      customerId: json['customerId'] is String
          ? json['customerId'] as String
          : (json['customerId'] as Map?)?['_id']?.toString() ?? '',
      billingStart: start,
      billingEnd: end,
      amount: resolvedAmount,
      status: resolvedStatus,
      dueDate: due,
      shareToken: json['shareToken']?.toString(),
      customerName: json['customerId'] is Map
          ? (json['customerId'] as Map)['name']?.toString()
          : null,
    );
  }
}
