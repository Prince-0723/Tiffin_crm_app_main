class TiffinLedgerEntry {
  const TiffinLedgerEntry({
    required this.action,
    required this.countAfter,
    required this.createdAt,
  });

  final String action;
  final int countAfter;
  final DateTime createdAt;

  factory TiffinLedgerEntry.fromJson(Map<String, dynamic> json) {
    DateTime? at;
    final raw = json['createdAt'];
    if (raw is String) {
      at = DateTime.tryParse(raw);
    }
    return TiffinLedgerEntry(
      action: json['action']?.toString() ?? '',
      countAfter: json['countAfter'] is num
          ? (json['countAfter'] as num).toInt()
          : int.tryParse('${json['countAfter']}') ?? 0,
      createdAt: at ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CustomerTiffinSnapshot {
  const CustomerTiffinSnapshot({
    required this.tiffinCount,
    required this.history,
  });

  final int tiffinCount;
  final List<TiffinLedgerEntry> history;

  factory CustomerTiffinSnapshot.fromJson(Map<String, dynamic> json) {
    final rawH = json['history'];
    final list = <TiffinLedgerEntry>[];
    if (rawH is List) {
      for (final e in rawH) {
        if (e is Map<String, dynamic>) {
          list.add(TiffinLedgerEntry.fromJson(e));
        }
      }
    }
    final tc = json['tiffinCount'];
    final count = tc is num
        ? tc.toInt()
        : int.tryParse('$tc') ?? 0;
    return CustomerTiffinSnapshot(tiffinCount: count, history: list);
  }
}
