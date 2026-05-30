import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _db = FirebaseDatabase.instance.ref();
  double _wallet = 0;
  double _totalEarnings = 0;
  int _completedJobs = 0;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  StreamSubscription<DatabaseEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = await StorageService.getUid() ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    _sub = _db.child('professionals/$uid').onValue.listen((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final wallet = (data['wallet'] ?? 0.0).toDouble();
      final totalEarnings = (data['totalEarnings'] ?? 0.0).toDouble();

      // Load earnings history
      final historySnap =
          await _db.child('professionals/$uid/earningsHistory').get();
      final histList = <Map<String, dynamic>>[];
      if (historySnap.exists && historySnap.value != null) {
        final histMap =
            Map<String, dynamic>.from(historySnap.value as Map);
        histMap.forEach((key, value) {
          final entry = Map<String, dynamic>.from(value as Map);
          histList.add(entry);
        });
        histList.sort((a, b) =>
            (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      }

      if (mounted) {
        setState(() {
          _wallet = wallet;
          _totalEarnings = totalEarnings;
          _completedJobs = histList.length;
          _history = histList;
          _loading = false;
        });
      }
    });
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(
        (timestamp is int) ? timestamp : timestamp.toInt());
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Wallet',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _load();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Wallet balance gradient card
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet,
                                  color: Colors.white70, size: 20),
                              const SizedBox(width: 8),
                              const Text('Available Balance',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rs. ${_wallet.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'After 10% platform commission',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    // Stats row
                    Transform.translate(
                      offset: const Offset(0, -1),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, -2))
                          ],
                        ),
                        child: Row(
                          children: [
                            _buildStatItem(
                              'Total Earned',
                              'Rs. ${_totalEarnings.toStringAsFixed(0)}',
                              Icons.trending_up,
                              AppColors.success,
                            ),
                            _buildVerticalDivider(),
                            _buildStatItem(
                              'Jobs Done',
                              '$_completedJobs',
                              Icons.check_circle_outline,
                              AppColors.primary,
                            ),
                            _buildVerticalDivider(),
                            _buildStatItem(
                              'Commission',
                              '10%',
                              Icons.percent,
                              AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Commission info box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color:
                                      AppColors.primary.withOpacity(0.15)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: AppColors.primary, size: 18),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    '10% platform fee is automatically deducted when customers pay. You receive 90% of the agreed price.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Earnings History',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 12),

                          if (_history.isEmpty)
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40),
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_outlined,
                                        size: 56,
                                        color: AppColors.textLight),
                                    const SizedBox(height: 12),
                                    const Text('No earnings yet',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 15)),
                                    const Text(
                                      'Complete jobs to see earnings here',
                                      style: TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._history.map((entry) {
                              final gross =
                                  (entry['grossAmount'] ?? 0.0).toDouble();
                              final commission =
                                  (entry['commission'] ?? 0.0).toDouble();
                              final net =
                                  (entry['netEarning'] ?? 0.0).toDouble();
                              final ts = entry['timestamp'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            Colors.black.withOpacity(0.04),
                                        blurRadius: 8)
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.payments_outlined,
                                          color: AppColors.success,
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Job Payment Received',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: AppColors.textPrimary)),
                                          Text(
                                            _formatDate(ts),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            'Gross: Rs. ${gross.toStringAsFixed(0)} | Fee: Rs. ${commission.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textLight),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '+Rs. ${net.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 50,
      width: 1,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
