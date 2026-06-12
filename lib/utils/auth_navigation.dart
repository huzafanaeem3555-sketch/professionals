import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Central routing after Firebase session is established.
class AuthNavigation {
  static Future<void> routeAfterAuth(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = await StorageService.isGuestSession();
    if (isGuest) {
      await StorageService.setSessionMeta(
        role: 'customer',
        gender: await StorageService.getGender() ?? 'male',
        verificationStatus: 'verified',
      );
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/customer-home');
      return;
    }
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
    final storedGender = await StorageService.getGender() ?? '';
    final genderFromBackend =
        me != null && me.containsKey('gender') ? me['gender'] : storedGender;
    final gender = (genderFromBackend?.toString() ?? '').trim().toLowerCase();
    final savedVerificationStatus =
        await StorageService.getVerificationStatus() ?? '';
    final verificationStatus =
        (me?['verificationStatus']?.toString() ?? savedVerificationStatus)
            .trim()
            .toLowerCase();
    final effectiveVerificationStatus = verificationStatus.isNotEmpty
        ? verificationStatus
        : (gender == 'female' ? 'pending' : 'verified');
    final isActive = me?['isActive'] == null
        ? effectiveVerificationStatus == 'verified'
        : me!['isActive'] == true;
    final femalePending = gender == 'female' &&
        (!isActive || effectiveVerificationStatus != 'verified');
    final profileCompleted =
        me?['profileCompleted'] == true || me?['profileCreated'] == true;

    await StorageService.setSessionMeta(
      role: role,
      gender: gender,
      verificationStatus: effectiveVerificationStatus,
    );

    if (!context.mounted) return;

    if (role.isEmpty || gender.isEmpty) {
      Navigator.pushReplacementNamed(context, '/role-selection');
      return;
    }

    if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin-dashboard');
      return;
    }

    if (!isActive && gender != 'female') {
      Navigator.pushReplacementNamed(
        context,
        '/gender-verification',
        arguments: role,
      );
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
