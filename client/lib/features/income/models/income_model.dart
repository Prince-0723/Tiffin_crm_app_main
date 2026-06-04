class IncomeModel {
  const IncomeModel({
    required this.id,
    required this.source,
    required this.amount,
    required this.date,
    this.notes,
    this.vendorId,
    this.createdAt,
    this.paymentMethod,
    this.referenceId,
  });

  final String id;
  final String source;
  final double amount;
  final DateTime date;
  final String? notes;
  final String? vendorId;
  final DateTime? createdAt;
  final String? paymentMethod;
  final String? referenceId;

  factory IncomeModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> m = json;
    if (json['data'] is Map<String, dynamic>) {
      m = json['data'] as Map<String, dynamic>;
    }
    return IncomeModel(
      id: m['_id']?.toString() ?? m['id']?.toString() ?? '',
      source: m['source']?.toString() ?? '',
      amount: (m['amount'] is num)
          ? (m['amount'] as num).toDouble()
          : double.tryParse('${m['amount']}') ?? 0,
      date: _parseDate(m['date']),
      notes: m['notes']?.toString(),
      vendorId: m['vendorId']?.toString(),
      createdAt: m['createdAt'] != null ? _parseDate(m['createdAt']) : null,
      paymentMethod: m['paymentMethod']?.toString(),
      referenceId: m['referenceId']?.toString(),
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'amount': amount,
        'date': date.toIso8601String().split('T').first,
        if (notes != null) 'notes': notes,
        if (vendorId != null) 'vendorId': vendorId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (referenceId != null) 'referenceId': referenceId,
      };
}
