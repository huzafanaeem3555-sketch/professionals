import 'package:flutter/material.dart';

/// Root navigator for API 401 redirects and auth navigation.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void navigateToLogin() {
  rootNavigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
}
