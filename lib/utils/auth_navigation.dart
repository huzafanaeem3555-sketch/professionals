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
        me = Map<String, dynamic>.from(res['data'] as Map);
      }
    } catch (_) {}

    final role = (me?['role']?.toString() ??
            await StorageService.getRole() ??
            '')
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

    if (!context.mounted) return;

    if (role.isEmpty) {
      Navigator.pushReplacementNamed(context, '/role-selection');
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

    if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin-dashboard');
      return;
    }

    if (role == 'professional') {
      final profileCompleted =
          me?['profileCompleted'] == true || me?['profileCreated'] == true;
      Navigator.pushReplacementNamed(
        context,
        profileCompleted ? '/professional-home' : '/professional-setup',
      );
      return;
    }

    Navigator.pushReplacementNamed(context, '/customer-home');
  }
}
