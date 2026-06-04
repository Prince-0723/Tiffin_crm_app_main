/// Daily order lifecycle — values must match backend `DailyOrder.status` strings.
enum OrderStatus {
  pending,
  processing,
  outForDelivery,
  delivered,
  cancelled;

  /// Value stored in DB and sent where the API expects a full status string.
  String get apiValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Label shown in Flutter UI (filter chips, badges).
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Parse from backend JSON `status` (and legacy aliases like `cooking`).
  static OrderStatus fromApi(String? value) {
    final v = (value ?? 'pending').toLowerCase().trim();
    switch (v) {
      case 'pending':
      case 'assigned':
      case 'to_process':
        return OrderStatus.pending;
      case 'processing':
      case 'cooking':
        return OrderStatus.processing;
      case 'out_for_delivery':
      case 'in_transit':
      case 'on_the_way':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'failed':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  /// Targets allowed for `PATCH /daily-orders/:id/status` body (`processing` | `out_for_delivery` | `delivered`).
  bool get isAllowedPatchTarget =>
      this == OrderStatus.processing ||
      this == OrderStatus.outForDelivery ||
      this == OrderStatus.delivered;

  /// Whether [next] is a valid PATCH target from [this] order (per backend transitions).
  bool canTransitionTo(OrderStatus next) {
    switch (next) {
      case OrderStatus.processing:
        return this == OrderStatus.pending;
      case OrderStatus.outForDelivery:
        return this == OrderStatus.pending || this == OrderStatus.processing;
      case OrderStatus.delivered:
        return this == OrderStatus.pending ||
            this == OrderStatus.processing ||
            this == OrderStatus.outForDelivery;
      default:
        return false;
    }
  }
}
