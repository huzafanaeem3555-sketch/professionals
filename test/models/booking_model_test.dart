import 'package:flutter_test/flutter_test.dart';
import 'package:service_connect/models/booking_model.dart';

void main() {
  group('BookingModel.fromMap', () {
    test(
        'uses proposed price fallback and reveals contact only after confirmation',
        () {
      final booking = BookingModel.fromMap({
        'bookingId': 'b1',
        'customerId': 'c1',
        'professionalId': 'p1',
        'serviceType': 'plumber',
        'status': 'confirmed',
        'proposedPrice': 2500,
        'otherUserPhone': '03001234567',
      });

      expect(booking.agreedPrice, 2500);
      expect(booking.platformCommission, 250);
      expect(booking.professionalEarnings, 2250);
      expect(booking.canShowContactPhone, isTrue);
    });

    test('keeps contact hidden for pending bookings', () {
      final booking = BookingModel.fromMap({
        'bookingId': 'b2',
        'customerId': 'c1',
        'professionalId': 'p1',
        'serviceType': 'electrician',
        'status': 'pending_professional_response',
        'proposedPrice': 1800,
        'otherUserPhone': '03001234567',
      });

      expect(booking.canShowContactPhone, isFalse);
    });

    test('parses scheduled time from iso string', () {
      final booking = BookingModel.fromMap({
        'bookingId': 'b3',
        'customerId': 'c1',
        'professionalId': 'p1',
        'serviceType': 'cleaner',
        'status': 'confirmed',
        'scheduledTime': '2026-05-25T10:30:00.000',
      });

      expect(booking.scheduledTime, isNotNull);
      expect(booking.scheduledTime, contains('2026-05-25'));
    });
  });
}
