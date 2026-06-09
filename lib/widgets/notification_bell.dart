import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../screens/notification_inbox_screen.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.iconColor = Colors.white});

  final Color iconColor;

  int _unreadCount(DatabaseEvent event) {
    if (!event.snapshot.exists || event.snapshot.value == null) return 0;
    final map = Map<String, dynamic>.from(event.snapshot.value as Map);
    return map.values.where((value) {
      if (value is! Map) return false;
      return Map<String, dynamic>.from(value)['read'] != true;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: StorageService.getUid()
          .then((uid) => uid ?? FirebaseAuth.instance.currentUser?.uid),
      builder: (context, uidSnapshot) {
        final uid = uidSnapshot.data;
        final button = Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationInboxScreen(),
                ),
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Icon(Icons.notifications_rounded, color: iconColor),
            ),
          ),
        );

        if (uid == null || uid.isEmpty) return button;

        return StreamBuilder<DatabaseEvent>(
          stream:
              FirebaseDatabase.instance.ref('userNotifications/$uid').onValue,
          builder: (context, snapshot) {
            final count = snapshot.hasData ? _unreadCount(snapshot.data!) : 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                button,
                if (count > 0)
                  Positioned(
                    top: 8,
                    right: 4,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 19, minHeight: 19),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
