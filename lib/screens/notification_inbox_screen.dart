import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/storage_service.dart';
import '../utils/constants.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  final _db = FirebaseDatabase.instance.ref();
  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadUid();
  }

  Future<void> _loadUid() async {
    final uid =
        await StorageService.getUid() ?? FirebaseAuth.instance.currentUser?.uid;
    if (mounted) setState(() => _uid = uid);
  }

  Future<void> _markAllRead() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    final snap = await _db.child('userNotifications/$uid').get();
    if (!snap.exists || snap.value == null) return;
    final updates = <String, Object?>{};
    final map = Map<String, dynamic>.from(snap.value as Map);
    for (final id in map.keys) {
      updates['userNotifications/$uid/$id/read'] = true;
    }
    if (updates.isNotEmpty) await _db.update(updates);
  }

  Future<void> _deleteNotification(String id) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || id.isEmpty) return;
    await _db.child('userNotifications/$uid/$id').remove();
  }

  List<Map<String, dynamic>> _parseNotifications(DatabaseEvent event) {
    if (!event.snapshot.exists || event.snapshot.value == null) return [];
    final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
    final list = raw.entries.map((entry) {
      final value = Map<String, dynamic>.from(entry.value as Map);
      value['id'] = entry.key;
      return value;
    }).toList();
    list.sort(
        (a, b) => _toInt(b['createdAt']).compareTo(_toInt(a['createdAt'])));
    return list;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'direct_call':
        return Icons.call_rounded;
      case 'direct_whatsapp':
        return Icons.chat_rounded;
      case 'new_booking':
        return Icons.assignment_turned_in_rounded;
      case 'price_offer':
        return Icons.payments_rounded;
      case 'booking_accepted':
        return Icons.check_circle_rounded;
      case 'customer_completed':
        return Icons.task_alt_rounded;
      case 'job_post':
        return Icons.work_outline_rounded;
      case 'job_offer':
        return Icons.local_offer_rounded;
      case 'job_offer_selected':
        return Icons.verified_rounded;
      case 'job_offer_countered':
        return Icons.price_change_rounded;
      case 'job_status_changed':
        return Icons.sync_alt_rounded;
      case 'payment_confirmed':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child:
                const Text('Mark read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: uid == null || uid.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DatabaseEvent>(
              stream:
                  _db.child('userNotifications/$uid').limitToLast(100).onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notifications = snapshot.hasData
                    ? _parseNotifications(snapshot.data!)
                    : <Map<String, dynamic>>[];

                if (notifications.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 64, color: AppColors.textLight),
                        SizedBox(height: 12),
                        Text('No notifications yet',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text(
                            'Customer and professional alerts will appear here.'),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final id = item['id']?.toString() ?? '';
                    final title = item['title']?.toString() ?? 'HirePro';
                    final body = item['body']?.toString() ?? '';
                    final type = item['type']?.toString() ?? '';
                    final read = item['read'] == true;
                    final createdAt = _toInt(item['createdAt']);
                    final time = createdAt > 0
                        ? DateFormat('dd MMM, h:mm a').format(
                            DateTime.fromMillisecondsSinceEpoch(createdAt))
                        : '';

                    return Dismissible(
                      key: ValueKey(id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteNotification(id),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          if (!read) {
                            await _db
                                .child('userNotifications/$uid/$id/read')
                                .set(true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: read
                                  ? AppColors.divider
                                  : AppColors.primary.withOpacity(0.35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: read
                                    ? AppColors.textLight.withOpacity(0.14)
                                    : AppColors.primary.withOpacity(0.12),
                                child: Icon(_iconForType(type),
                                    color: read
                                        ? AppColors.textSecondary
                                        : AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: read
                                                  ? FontWeight.w600
                                                  : FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (!read)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (body.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(body,
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              height: 1.3)),
                                    ],
                                    if (time.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(time,
                                          style: const TextStyle(
                                              color: AppColors.textLight,
                                              fontSize: 12)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
