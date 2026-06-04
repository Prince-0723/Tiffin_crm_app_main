// Mirrors server wallet + subscription helpers (customerDetails / subscriptionBalance.js)
// so portal fallback stays aligned when /customer/me/balance is unavailable.

double effectiveWalletBalance(Map<String, dynamic> customer) {
  double n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  final maxWallet = n(customer['walletBalance']) > n(customer['balance'])
      ? n(customer['walletBalance'])
      : n(customer['balance']);
  return maxWallet < 0 ? 0 : maxWallet;
}

// Same rules as server/utils/subscriptionBalance.js → effectiveRemaining.
double effectiveSubscriptionRemaining(Map<String, dynamic>? subscription) {
  if (subscription == null || subscription.isEmpty) return 0;
  final rb = subscription['remainingBalance'];
  if (rb != null) {
    if (rb is num) return rb.toDouble();
    return double.tryParse('$rb') ?? 0;
  }
  final total = _toDouble(subscription['totalAmount']);
  if (total > 0) return total;
  return _toDouble(subscription['paidAmount']);
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}
