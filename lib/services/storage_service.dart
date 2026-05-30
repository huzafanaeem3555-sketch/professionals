import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences wrapper for session persistence.
class StorageService {
  static const String _keyRole = 'user_role';
  static const String _keyProfessionalPhone = 'professional_phone';
  static const String _keyCustomerId = 'customer_id';
  static const String _keyToken = 'auth_token';
  static const String _keyUid = 'user_uid';
  static const String _keyIdToken = 'id_token';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserPhoto = 'user_photo';

  static Future<void> setUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUid, uid);
  }

  static Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUid);
  }

  static Future<void> setRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> setIdToken(String idToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIdToken, idToken);
  }

  static Future<String?> getIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIdToken);
  }

  static Future<void> setUserDetails({
    required String name,
    required String email,
    required String photo,
    String? idToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserPhoto, photo);
    if (idToken != null && idToken.isNotEmpty) {
      await prefs.setString(_keyIdToken, idToken);
    }
  }

  static Future<Map<String, String>> getUserDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'name': prefs.getString(_keyUserName) ?? '',
        'email': prefs.getString(_keyUserEmail) ?? '',
        'photo': prefs.getString(_keyUserPhoto) ?? '',
        'idToken': prefs.getString(_keyIdToken) ?? '',
      };
    } catch (_) {
      await clearAll();
      return {'name': '', 'email': '', 'photo': '', 'idToken': ''};
    }
  }

  static Future<void> setProfessionalPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfessionalPhone, phone);
  }

  static Future<String?> getProfessionalPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProfessionalPhone);
  }

  static Future<String> getCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_keyCustomerId);
    if (id == null || id.isEmpty) {
      final uid = prefs.getString(_keyUid);
      id = uid ?? 'customer_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_keyCustomerId, id);
    }
    return id;
  }

  static Future<void> clearRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRole);
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
  }
}
