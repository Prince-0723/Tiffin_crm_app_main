import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin_crm/features/subscriptions/models/subscription_model.dart';

/// Regression: API exposes pay-later ledger extras on subscription list payloads.
void main() {
  test('SubscriptionModel parses consumptionExposure and creditHeadroom', () {
    final m = SubscriptionModel.fromJson({
      '_id': '507f1f77bcf86cd799439011',
      'customerId': '507f1f77bcf86cd799439012',
      'planId': '507f1f77bcf86cd799439013',
      'startDate': '2026-01-01T00:00:00.000Z',
      'endDate': '2026-01-31T00:00:00.000Z',
      'status': 'active',
      'payLater': true,
      'totalAmount': 3000,
      'paidAmount': 500,
      'remainingBalance': 2000,
      'consumptionExposure': 250.5,
      'creditHeadroom': 49.5,
    });

    expect(m.payLater, true);
    expect(m.consumptionExposure, 250.5);
    expect(m.creditHeadroom, 49.5);
  });

  test('SubscriptionModel allows null ledger extras', () {
    final m = SubscriptionModel.fromJson({
      '_id': '507f1f77bcf86cd799439011',
      'customerId': '507f1f77bcf86cd799439012',
      'planId': '507f1f77bcf86cd799439013',
      'startDate': '2026-01-01T00:00:00.000Z',
      'endDate': '2026-01-31T00:00:00.000Z',
      'status': 'active',
    });

    expect(m.consumptionExposure, null);
    expect(m.creditHeadroom, null);
  });
}
