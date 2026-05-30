import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../screens/notification_inbox_screen.dart';
import '../services/storage_service.dart';

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
      future: StorageService.getUid().then((uid) => uid ?? FirebaseAuth.instance.currentUser?.uid),
      builder: (context, uidSnapshot) {
        final uid = uidSnapshot.data;
        final button = IconButton(
          icon: Icon(Icons.notifications_rounded, color: iconColor),
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationInboxScreen()),
            );
          },
        );

        if (uid == null || uid.isEmpty) return button;

        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('userNotifications/$uid').onValue,
          builder: (context, snapshot) {
            final count = snapshot.hasData ? _unreadCount(snapshot.data!) : 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                button,
                if (count > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B6B),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
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
