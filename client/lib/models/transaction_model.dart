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
  /// Ledger origin when present, e.g. [order_processing] / [order_delivered] for meal deductions.
  final String? source;
  final List<CustomerDetailTransactionItem> items;

  /// Money in (wallet top-up, etc.). Everything else is shown as outflow (−₹, red).
  bool get isCredit => type == 'credit';

  /// Display amount always non-negative; sign comes from [isCredit].
  double get displayAmount => amount.abs();

  /// Whether this transaction was created from an order lifecycle event.
  bool get isOrderTransaction =>
      source == 'order_delivered' || source == 'order_processing';

  /// Whether this transaction is part of the customer's subscription ledger.
  bool get isSubscriptionTransaction =>
      source == 'order_delivered' ||
      source == 'order_processing' ||
      source == 'subscription_dues_payment';

  /// Whether this transaction affects wallet balance.
  bool get isWalletTransaction {
    if (id.startsWith('pay_') && isCredit) return true;
    return source == 'wallet_topup' ||
        source == 'wallet_deduction' ||
        source == 'extra_charge_wallet' ||
        source == 'extra_charge_subscription';
  }

  /// Wallet-signed amount (credits positive, debits negative).
  double get walletSignedAmount {
    if (!isWalletTransaction) return 0;
    return isCredit ? displayAmount : -displayAmount;
  }

  /// Subscription-signed amount (subscription credits positive, subscription debits negative).
  double get subscriptionSignedAmount {
    if (!isSubscriptionTransaction) return 0;
    return isCredit ? displayAmount : -displayAmount;
  }

  /// Hide the amount label for delivered-order ledger entries when shown in status views.
  bool get hideAmountForDeliveredStatus => source == 'order_delivered';

  /// Table / chip label — API may send other type strings for debits.
  String get typeLabel => isCredit ? 'Credit' : 'Debit';

  /// Returns the amount string to show in transaction rows.
  String amountLabel({bool hideDeliveredAmount = false}) {
    if (hideDeliveredAmount && hideAmountForDeliveredStatus) {
      return '';
    }
    return '${isCredit ? '+' : '-'}₹${displayAmount.toStringAsFixed(0)}';
  }

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
        : (src == 'order_delivered' || src == 'order_processing'
            ? 'debit'
            : rawType);
    if (src == 'order_delivered' || src == 'order_processing') {
      resolvedType = 'debit';
    }

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
