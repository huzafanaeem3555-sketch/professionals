import 'dart:async';

import 'package:flutter/material.dart';

void showTimedSnackBar(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(snackBar);
  Timer(const Duration(seconds: 3), () {
    if (context.mounted) {
      messenger.hideCurrentSnackBar();
    }
  });
}
