import 'package:flutter/material.dart';

/// Google Maps / Geocoding — must match AndroidManifest meta-data API key.
class MapConstants {
  static const String googleMapsApiKey =
      'AIzaSyA2jauIr0PY3aEEsAEJ0CFTGWi_yaTSMiw';
}

/// API Constants for Backend Connection
class ApiConstants {
  // ============================================================
  // ✅ RAILWAY PRODUCTION URL (LIVE - DO NOT CHANGE)
  // ============================================================
  static const String railwayBaseUrl = 'https://professionals-production-c9b2.up.railway.app/api';

  // ============================================================
  // LOCAL DEVELOPMENT URLs (For testing only)
  // ============================================================
  static const String localBaseUrl = 'http://192.168.1.10:5000/api';
  static const String emulatorBaseUrl = 'http://10.0.2.2:5000/api';
  static const String localhostUrl = 'http://localhost:5000/api';

  // ============================================================
  // 🔥 IMPORTANT: Set this to FALSE for Railway Production
  // 🔥 Set this to TRUE for Local Testing
  // ============================================================
  static const bool isDevelopment = false;  // ✅ PRODUCTION MODE

  static String get baseUrl {
    // For local development testing
    if (isDevelopment) {
      return localBaseUrl;
    }

    // For production (Railway)
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;

    return railwayBaseUrl;
  }

  /// Smart base URL with auto-detection
  static String get smartBaseUrl {
    if (!isDevelopment) {
      return railwayBaseUrl;
    }
    return localBaseUrl;
  }

  /// Fallback URLs for retry logic
  static List<String> get fallbackBaseUrls {
    if (isDevelopment) {
      return [
        localBaseUrl,
        emulatorBaseUrl,
        localhostUrl,
      ];
    }
    return [
      railwayBaseUrl,
    ];
  }

  // ============================================================
  // API ENDPOINTS
  // ============================================================

  // Authentication
  static const String authGoogle = '/auth/google';
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authLogout = '/auth/logout';

  // Professionals
  static const String professionals = '/professionals';
  static const String professionalsAll = '/professionals/all';
  static const String nearbyProfessionals = '/professionals/nearby';
  static const String professionalProfile = '/professionals';
  static const String updateProfile = '/professionals/profile';
  static const String toggleAvailability = '/professionals/availability';
  static const String uploadPhoto = '/professionals/upload-photo';
  static const String uploadPortfolio = '/professionals/upload-portfolio';
  static const String earningsEndpoint = '/professionals/earnings';

  // Bookings
  static const String bookings = '/bookings';
  static const String myBookings = '/bookings/my';
  static const String activeBookings = '/bookings/active';
  static const String acceptBooking = '/bookings';
  static const String rejectBooking = '/bookings';
  static const String cancelBookingEndpoint = '/bookings';
  static const String startJobEndpoint = '/bookings';
  static const String completeJobEndpoint = '/bookings';
  static const String rateBookingEndpoint = '/bookings';
  static const String counterBooking = '/bookings';

  // Search
  static const String search = '/search';
  static const String searchSuggest = '/search/suggest';

  // Chat
  static const String sendMessage = '/chat/send';
  static const String getMessages = '/chat/messages';
  static const String conversations = '/chat/conversations';

  // Geolocation
  static const String nearbyByLocation = '/geolocation/nearby';
  static const String professionalLocation = '/geolocation/professional-location';
  static const String updateLocation = '/geolocation/update-location';

  // Users
  static const String users = '/users';
  static const String userProfile = '/users/profile';
  static const String wallet = '/wallet';
  static const String transactions = '/wallet/transactions';

  // AI
  static const String aiMessage = '/ai/chat';
  static const String aiRecommendService = '/ai/recommend-service';

  // Utils
  static const String validateProfile = '/utils/validate-profile';
  static const String resetTestData = '/utils/reset-test-data';

  // Admin
  static const String adminLogin = '/admin/login';
  static const String adminStats = '/admin/stats';
  static const String adminProfessionals = '/admin/professionals';
  static const String adminCustomers = '/admin/customers';
  static const String adminBookings = '/admin/bookings';
  static const String adminTransactions = '/admin/transactions';
  static const String adminUsers = '/admin/users';
}

/// App Colors
class AppColors {
  static const Color primary = Color(0xFF0F4C5C);
  static const Color primaryLight = Color(0xFF2B6F82);
  static const Color primaryDark = Color(0xFF0A2F39);
  static const Color accent = Color(0xFFC68A2B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color background = Color(0xFFF4F7F6);
  static const Color surfaceLight = Color(0xFFEAF0EE);
  static const Color textPrimary = Color(0xFF13212B);
  static const Color textSecondary = Color(0xFF5D6B74);
  static const Color textLight = Color(0xFF8C98A0);
  static const Color divider = Color(0xFFD8E1DE);
  static const Color star = Color(0xFFFBBF24);
  static const Color groqPurple = Color(0xFF7C3AED);
  static const Color available = Color(0xFF10B981);
  static const Color unavailable = Color(0xFF94A3B8);
}

/// App Strings
class AppStrings {
  static const String appName = 'Professionals';
  static const String appTagline = 'Find trusted professionals near you';

  static const List<Map<String, dynamic>> serviceCategories = [
    {'name': 'Plumber', 'icon': '🔧', 'key': 'plumber'},
    {'name': 'Electrician', 'icon': '⚡', 'key': 'electrician'},
    {'name': 'Carpenter', 'icon': '🪚', 'key': 'carpenter'},
    {'name': 'AC Mechanic', 'icon': '❄️', 'key': 'ac_mechanic'},
    {'name': 'Painter', 'icon': '🎨', 'key': 'painter'},
    {'name': 'Cleaner', 'icon': '🧹', 'key': 'cleaner'},
    {'name': 'Tutor', 'icon': '📚', 'key': 'tutor'},
    {'name': 'Driver', 'icon': '🚗', 'key': 'driver'},
    {'name': 'Chef', 'icon': '👨‍🍳', 'key': 'chef'},
    {'name': 'Beautician', 'icon': '💄', 'key': 'beautician'},
    {'name': 'IT Technician', 'icon': '💻', 'key': 'it_technician'},
    {'name': 'Security Guard', 'icon': '👮', 'key': 'security_guard'},
    {'name': 'Gardener', 'icon': '🌱', 'key': 'gardener'},
    {'name': 'Mechanic', 'icon': '🔩', 'key': 'mechanic'},
    {'name': 'Welder', 'icon': '🔥', 'key': 'welder'},
    {'name': 'Mason', 'icon': '🧱', 'key': 'mason'},
  ];

  static const List<String> popularServices = [
    'plumber',
    'electrician',
    'carpenter',
    'ac_mechanic',
    'painter',
    'cleaner',
  ];
}

/// Service Labels Helper
class ServiceLabels {
  static Map<String, dynamic> labelFor(String key) {
    final cat = AppStrings.serviceCategories.firstWhere(
          (c) => c['key'] == key,
      orElse: () => {'name': key, 'icon': '📌', 'key': key},
    );
    return cat;
  }

  static String getIcon(String key) {
    final cat = labelFor(key);
    return cat['icon'] as String;
  }

  static String getName(String key) {
    final cat = labelFor(key);
    return cat['name'] as String;
  }
}
