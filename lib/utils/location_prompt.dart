import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../utils/constants.dart';
import '../utils/snackbar_helper.dart';

Future<bool> ensureLocationEnabled(
  BuildContext context, {
  String message =
      'Please turn on location so HirePro can find nearby professionals and show accurate map tracking.',
}) async {
  final service = LocationService();
  if (await service.isLocationAvailable()) return true;
  if (!context.mounted) return false;

  final openSettings = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Turn on location'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.location_on_rounded),
          label: const Text('Turn on'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );

  if (openSettings != true) {
    if (context.mounted) {
      showTimedSnackBar(
        context,
        const SnackBar(
          content:
              Text('Location is off. Nearby matching may be less accurate.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
    return false;
  }

  await service.openLocationSettings();
  await Future.delayed(const Duration(seconds: 2));
  final enabled = await service.isLocationAvailable();
  if (!enabled && context.mounted) {
    showTimedSnackBar(
      context,
      const SnackBar(
        content:
            Text('Location is still off. Turn it on from device settings.'),
        backgroundColor: AppColors.warning,
      ),
    );
  }
  return enabled;
}
