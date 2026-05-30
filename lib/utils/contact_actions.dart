import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

enum ContactMethod { call, whatsapp }

String normalizeDialablePhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+')) return digits;
  if (digits.startsWith('0')) {
    return '+92${digits.substring(1)}';
  }
  if (digits.startsWith('92')) {
    return '+$digits';
  }
  return digits;
}

Uri contactUriFor({
  required ContactMethod method,
  required String phoneNumber,
  String? message,
}) {
  final normalized = normalizeDialablePhone(phoneNumber);
  final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
  switch (method) {
    case ContactMethod.call:
      return Uri.parse('tel:$normalized');
    case ContactMethod.whatsapp:
      final encodedMessage = Uri.encodeComponent(
        message ??
            'Assalam-o-Alaikum, I want to contact you from Service Connect.',
      );
      return Uri.parse('https://wa.me/$digits?text=$encodedMessage');
  }
}

Future<bool> launchContactUri(Uri uri) async {
  try {
    if (uri.host == 'wa.me') {
      final phone = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      final text = uri.queryParameters['text'] ?? '';
      final appUri = Uri(
        scheme: 'whatsapp',
        host: 'send',
        queryParameters: {
          'phone': phone,
          if (text.isNotEmpty) 'text': text,
        },
      );
      try {
        if (await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
    }
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: Sometimes canLaunchUrl fails on Android 11+ despite queries, so try launching anyway
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('Could not launch $uri: $e');
    return false;
  }
}
