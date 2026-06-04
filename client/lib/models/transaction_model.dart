/// Single merged transaction row (ledger + legacy payments).
class CustomerDetailTransaction {
  const CustomerDetailTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.paymentMode,
    this.source,
    required this.items,
  });

  final String id;
  final String date;
  final String description;
  final double amount;
  final String type;
  final String paymentMode;
  /// Ledger origin when present, e.g. [order_delivered] for meal deductions.
  final String? source;
  final List<CustomerDetailTransactionItem> items;

  /// Money in (wallet top-up, etc.). Everything else is shown as outflow (−₹, red).
  bool get isCredit => type == 'credit';

  /// Display amount always non-negative; sign comes from [isCredit].
  double get displayAmount => amount.abs();

  /// Table / chip label — API may send other type strings for debits.
  String get typeLabel => isCredit ? 'Credit' : 'Debit';

  factory CustomerDetailTransaction.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = <CustomerDetailTransactionItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(CustomerDetailTransactionItem.fromJson(e));
        }
      }
    }
    final rawType = (json['type']?.toString() ?? '').trim().toLowerCase();
    final src = json['source']?.toString();
    String resolvedType = rawType.isNotEmpty
        ? rawType
        : (src == 'order_delivered' ? 'debit' : rawType);
    if (src == 'order_delivered') resolvedType = 'debit';

    return CustomerDetailTransaction(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount:
          (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0,
      type: resolvedType,
      paymentMode: json['paymentMode']?.toString() ?? '',
      source: src,
      items: list,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'description': description,
        'amount': amount,
        'type': type,
        'paymentMode': paymentMode,
        if (source != null) 'source': source,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class CustomerDetailTransactionItem {
  const CustomerDetailTransactionItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final double quantity;
  final double unitPrice;

  factory CustomerDetailTransactionItem.fromJson(Map<String, dynamic> json) {
    return CustomerDetailTransactionItem(
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toDouble()
          : 1,
      unitPrice: (json['unitPrice'] is num)
          ? (json['unitPrice'] as num).toDouble()
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}
