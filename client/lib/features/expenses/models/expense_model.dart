class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
    this.vendorId,
    this.createdAt,
    this.paymentMethod,
    this.tags,
    this.attachmentUrl,
  });

  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? notes;
  final String? vendorId;
  final DateTime? createdAt;
  final String? paymentMethod;
  final List<String>? tags;
  final String? attachmentUrl;

  static const List<String> categories = [
    'food',
    'transport',
    'salary',
    'rent',
    'utilities',
    'marketing',
    'equipment',
    'maintenance',
    'misc',
  ];

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> m = json;
    if (json['data'] is Map<String, dynamic>) {
      m = json['data'] as Map<String, dynamic>;
    }
    return ExpenseModel(
      id: m['_id']?.toString() ?? m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      amount: (m['amount'] is num)
          ? (m['amount'] as num).toDouble()
          : double.tryParse('${m['amount']}') ?? 0,
      category: m['category']?.toString() ?? 'misc',
      date: _parseDate(m['date']),
      notes: m['notes']?.toString(),
      vendorId: m['vendorId']?.toString(),
      createdAt: m['createdAt'] != null ? _parseDate(m['createdAt']) : null,
      paymentMethod: m['paymentMethod']?.toString(),
      tags: m['tags'] is List
          ? (m['tags'] as List).map((e) => e.toString()).toList()
          : null,
      attachmentUrl: m['attachmentUrl']?.toString(),
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
        'title': title,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String().split('T').first,
        if (notes != null) 'notes': notes,
        if (vendorId != null) 'vendorId': vendorId,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (tags != null) 'tags': tags,
      };

  ExpenseModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? notes,
    String? vendorId,
    DateTime? createdAt,
    String? paymentMethod,
    List<String>? tags,
    String? attachmentUrl,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      vendorId: vendorId ?? this.vendorId,
      createdAt: createdAt ?? this.createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tags: tags ?? this.tags,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }
}
