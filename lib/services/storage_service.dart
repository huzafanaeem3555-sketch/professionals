import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserPhoto = 'user_photo';
  static const String _keyGender = 'user_gender';
  static const String _keyVerificationStatus = 'verification_status';
  static const String _keyAdminSession = 'admin_session_active';
  static const String _keyAdminToken = 'admin_auth_token';
  static const String _keyGuestMode = 'guest_mode';
  static const String _keyCachedJobPosts = 'cached_job_posts';

  static Future<void> setUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUid, uid);
  }

  static Future<void> startGuestSession() async {
    final prefs = await SharedPreferences.getInstance();
    final guestId = prefs.getString(_keyUid) ??
        'guest_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setBool(_keyGuestMode, true);
    await prefs.setString(_keyUid, guestId);
    await prefs.setString(_keyRole, 'customer');
    await prefs.setString(_keyUserName, 'Guest Customer');
  }

  static Future<bool> isGuestSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGuestMode) == true;
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

  static Future<void> setGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGender, gender);
  }

  static Future<String?> getGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGender);
  }

  static Future<void> setVerificationStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVerificationStatus, status);
  }

  static Future<String?> getVerificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVerificationStatus);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
  }

  static Future<void> setAdminSessionActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAdminSession, active);
  }

  static Future<bool> isAdminSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAdminSession) == true;
  }

  static Future<void> clearAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAdminSession);
    await prefs.remove(_keyAdminToken);
  }

  static Future<void> setAdminToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAdminToken, token);
  }

  static Future<String?> getAdminToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminToken);
  }

  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRole);
    await prefs.remove(_keyProfessionalPhone);
    await prefs.remove(_keyCustomerId);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUid);
    await prefs.remove(_keyIdToken);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserPhoto);
    await prefs.remove(_keyGender);
    await prefs.remove(_keyVerificationStatus);
    await prefs.remove(_keyGuestMode);
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
    String? phone,
    String? idToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserPhoto, photo);
    if (phone != null && phone.isNotEmpty) {
      await prefs.setString(_keyUserPhone, phone);
    }
    if (idToken != null && idToken.isNotEmpty) {
      await prefs.setString(_keyIdToken, idToken);
    }
  }

  static Future<void> setSessionMeta({
    String? role,
    String? gender,
    String? verificationStatus,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (role != null && role.isNotEmpty) {
      await prefs.setString(_keyRole, role);
    }
    if (gender != null && gender.isNotEmpty) {
      await prefs.setString(_keyGender, gender);
    }
    if (verificationStatus != null && verificationStatus.isNotEmpty) {
      await prefs.setString(_keyVerificationStatus, verificationStatus);
    }
  }

  static Future<Map<String, String>> getUserDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'name': prefs.getString(_keyUserName) ?? '',
        'email': prefs.getString(_keyUserEmail) ?? '',
        'phone': prefs.getString(_keyUserPhone) ?? '',
        'photo': prefs.getString(_keyUserPhoto) ?? '',
        'idToken': prefs.getString(_keyIdToken) ?? '',
      };
    } catch (_) {
      await clearAll();
      return {'name': '', 'email': '', 'phone': '', 'photo': '', 'idToken': ''};
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

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _jobExpired(Map<String, dynamic> job) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = _toInt(job['expiresAt']);
    final assignedExpiresAt = _toInt(job['assignedExpiresAt']);
    return (expiresAt > 0 && expiresAt <= now) ||
        (assignedExpiresAt > 0 && assignedExpiresAt <= now);
  }

  static Future<void> cacheJobPosts(List<Map<String, dynamic>> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    final active = jobs.where((job) => !_jobExpired(job)).toList();
    await prefs.setString(_keyCachedJobPosts, jsonEncode(active));
  }

  static Future<List<Map<String, dynamic>>> getCachedJobPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCachedJobPosts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final jobs = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((job) => !_jobExpired(job))
          .toList();
      if (jobs.length != decoded.length) {
        await cacheJobPosts(jobs);
      }
      return jobs;
    } catch (_) {
      await prefs.remove(_keyCachedJobPosts);
      return [];
    }
  }

  static Future<Map<String, dynamic>> addCachedJobPost(
    Map<String, dynamic> job,
  ) async {
    final jobs = await getCachedJobPosts();
    final postId = job['postId']?.toString().isNotEmpty == true
        ? job['postId'].toString()
        : 'local_${DateTime.now().millisecondsSinceEpoch}';
    final data = {
      ...job,
      'postId': postId,
      'status': job['status'] ?? 'open',
      'createdAt': job['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'isLocalOnly': job['isLocalOnly'] ?? true,
    };
    jobs.removeWhere((item) => item['postId']?.toString() == postId);
    jobs.insert(0, data);
    await cacheJobPosts(jobs);
    return data;
  }
}
