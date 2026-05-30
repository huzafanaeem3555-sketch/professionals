import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/role-selection');
  }
}
