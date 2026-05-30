import 'package:flutter_test/flutter_test.dart';
import 'package:service_connect/models/professional_model.dart';

void main() {
  group('ProfessionalModel.fromMap', () {
    test('parses nested location and business metadata', () {
      final professional = ProfessionalModel.fromMap({
        'uid': 'pro_1',
        'phoneNumber': '03001234567',
        'name': 'Ali Electric Works',
        'services': ['electrician'],
        'description': 'Fast response for residential jobs',
        'rating': 4.8,
        'hourlyRate': 1800,
        'completedJobs': 42,
        'totalRatings': 19,
        'experienceYears': 6,
        'isVerified': true,
        'distance': 3.2,
        'location': {
          'lat': 24.8607,
          'lng': 67.0011,
          'address': 'Karachi',
        },
      });

      expect(professional.uid, 'pro_1');
      expect(professional.phone, '03001234567');
      expect(professional.location.address, 'Karachi');
      expect(professional.hourlyRate, 1800);
      expect(professional.completedJobs, 42);
      expect(professional.isVerified, isTrue);
      expect(professional.distanceText, '3.2 km');
    });

    test('returns safe defaults when optional data is missing', () {
      final professional = ProfessionalModel.fromMap({
        'uid': 'pro_2',
        'name': 'Basic Pro',
        'services': ['cleaner'],
      });

      expect(professional.rating, 0);
      expect(professional.distanceText, 'N/A');
      expect(professional.portfolio, isEmpty);
    });
  });
}
