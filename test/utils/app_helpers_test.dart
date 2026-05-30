import 'package:flutter_test/flutter_test.dart';
import 'package:service_connect/utils/helpers.dart';

void main() {
  group('AppHelpers', () {
    test('formats currency in PKR style', () {
      expect(AppHelpers.formatCurrency(950), 'Rs. 950');
      expect(AppHelpers.formatCurrency(12500), 'Rs. 12,500');
    });

    test('returns clean labels for negotiation statuses', () {
      expect(
        AppHelpers.getStatusLabel('pending_professional_response'),
        'Awaiting Professional',
      );
      expect(AppHelpers.getStatusLabel('completed'), 'Completed');
    });

    test('calculates commission and earnings', () {
      expect(AppHelpers.calculateCommission(2000), 200);
      expect(AppHelpers.calculateEarnings(2000), 1800);
    });
  });
}
