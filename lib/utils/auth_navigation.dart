import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Central routing after Firebase session is established.
class AuthNavigation {
  static Future<void> routeAfterAuth(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final savedUid = await StorageService.getUid();
    final savedToken = await StorageService.getToken();
    if (user == null &&
        (savedUid == null ||
            savedUid.isEmpty ||
            savedToken == null ||
            savedToken.isEmpty)) {
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    Map<String, dynamic>? me;
    try {
      final res = await ApiService().getMe();
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        me = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : data;
      }
    } catch (_) {}

    final role =
        (me?['role']?.toString() ?? await StorageService.getRole() ?? '')
            .trim()
            .toLowerCase();
    final gender = (me?['gender']?.toString() ??
            await StorageService.getGender() ??
            'male')
        .trim()
        .toLowerCase();
    final verificationStatus = (me?['verificationStatus']?.toString() ??
            await StorageService.getVerificationStatus() ??
            'verified')
        .trim()
        .toLowerCase();
    final isActive = me?['isActive'] == null
        ? verificationStatus == 'verified'
        : me!['isActive'] == true;
    final femalePending =
        gender == 'female' && (!isActive || verificationStatus != 'verified');
    final profileCompleted =
        me?['profileCompleted'] == true || me?['profileCreated'] == true;

    await StorageService.setSessionMeta(
      role: role,
      gender: gender,
      verificationStatus: verificationStatus,
    );

    if (!context.mounted) return;

    if (role.isEmpty) {
      Navigator.pushReplacementNamed(context, '/role-selection');
      return;
    }

    if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin-dashboard');
      return;
    }

    if (role == 'professional') {
      if (!profileCompleted) {
        Navigator.pushReplacementNamed(context, '/professional-setup');
        return;
      }
      if (femalePending) {
        Navigator.pushReplacementNamed(
          context,
          '/gender-verification',
          arguments: role,
        );
        return;
      }
      Navigator.pushReplacementNamed(
        context,
        '/professional-home',
      );
      return;
    }

    if (femalePending) {
      Navigator.pushReplacementNamed(
        context,
        '/gender-verification',
        arguments: role,
      );
      return;
    }

    Navigator.pushReplacementNamed(context, '/customer-home');
  }
}
