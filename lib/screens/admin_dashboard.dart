import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../utils/constants.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshData() {
    final adminProv = Provider.of<AdminProvider>(context, listen: false);
    adminProv.fetchAll();
    adminProv.startRealtimePolling();
  }

  Future<void> _deleteUser(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete User', style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to delete user "$name"? All their data, bookings, payments, and transactions will be removed.',
            style: TextStyle(color: Colors.grey[350])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await Provider.of<AdminProvider>(context, listen: false)
          .deleteUser(uid);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green),
        );
        _refreshData();
      }
    }
  }

  Future<void> _deleteBooking(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Delete Booking', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to delete this booking and its associated payments/transactions?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await Provider.of<AdminProvider>(context, listen: false)
          .deleteBooking(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Booking deleted successfully'),
              backgroundColor: Colors.green),
        );
        _refreshData();
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Clear App Data', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete all customers, professionals, bookings, transactions, chats and payments. Admin user will remain.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child:
                const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await Provider.of<AdminProvider>(context, listen: false)
          .clearAllData();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All app data cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshData();
      }
    }
  }

  Future<void> _editProfessional(Map<String, dynamic> p) async {
    final nameCtrl =
        TextEditingController(text: p['displayName']?.toString() ?? '');
    final phoneCtrl =
        TextEditingController(text: p['phoneNumber']?.toString() ?? '');
    final ratingCtrl =
        TextEditingController(text: (p['rating'] ?? 0).toString());
    final experienceCtrl =
        TextEditingController(text: (p['experienceYears'] ?? 0).toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Edit Professional',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _adminField(nameCtrl, 'Name'),
              const SizedBox(height: 10),
              _adminField(phoneCtrl, 'Phone'),
              const SizedBox(height: 10),
              _adminField(ratingCtrl, 'Rating 0-5',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              _adminField(experienceCtrl, 'Experience Years',
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final success = await Provider.of<AdminProvider>(context, listen: false)
          .updateProfessional(p['uid']?.toString() ?? '', {
        'displayName': nameCtrl.text.trim(),
        'phoneNumber': phoneCtrl.text.trim(),
        'rating': double.tryParse(ratingCtrl.text.trim()) ?? 0,
        'experienceYears': int.tryParse(experienceCtrl.text.trim()) ?? 0,
      });
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Professional updated')),
        );
      }
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
    ratingCtrl.dispose();
    experienceCtrl.dispose();
  }

  Widget _adminField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Future<void> _showProfessionalReviews(Map<String, dynamic> p) async {
    final uid = p['uid']?.toString() ?? '';
    if (uid.isEmpty) return;
    final adminProv = Provider.of<AdminProvider>(context, listen: false);
    final reviews = await adminProv.getProfessionalReviews(uid);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Feedbacks', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: reviews.isEmpty
              ? const Text('No feedback yet',
                  style: TextStyle(color: Colors.white70))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index] as Map;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${review['customerName'] ?? 'Customer'} - ${review['rating'] ?? 0} star',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        review['review']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () async {
                          await adminProv.deleteProfessionalReview(
                            uid,
                            review['reviewId']?.toString() ?? '',
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProv = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Admin Console',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded,
                color: Colors.orangeAccent),
            onPressed: _clearAllData,
            tooltip: 'Clear All Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              await adminProv.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/admin-login');
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Stats'),
            Tab(icon: Icon(Icons.engineering_rounded), text: 'Professionals'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Customers'),
            Tab(icon: Icon(Icons.book_online_rounded), text: 'Bookings'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Transactions'),
          ],
        ),
      ),
      body: adminProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(adminProv),
                _buildProfessionalsTab(adminProv),
                _buildCustomersTab(adminProv),
                _buildBookingsTab(adminProv),
                _buildTransactionsTab(adminProv),
              ],
            ),
    );
  }

  Widget _buildStatsTab(AdminProvider adminProv) {
    final stats = adminProv.stats;
    if (stats == null) {
      return const Center(
          child: Text('No stats available',
              style: TextStyle(color: Colors.white)));
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Text(
              'Marketplace Performance',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Realtime insights and financial commission status.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),

            // Grid of Stats
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.55,
              children: [
                _buildPremiumStatCard(
                  'Total Professionals',
                  stats['totalProfessionals']?.toString() ?? '0',
                  Icons.engineering_rounded,
                  Colors.blueAccent,
                ),
                _buildPremiumStatCard(
                  'Total Customers',
                  stats['totalCustomers']?.toString() ?? '0',
                  Icons.people_alt_rounded,
                  Colors.purpleAccent,
                ),
                _buildPremiumStatCard(
                  'Completed Jobs',
                  stats['totalCompletedJobs']?.toString() ?? '0',
                  Icons.task_alt_rounded,
                  Colors.greenAccent,
                ),
                _buildPremiumStatCard(
                  'Commission Earned',
                  'PKR ${stats['totalCommission'] ?? 0}',
                  Icons.payments_rounded,
                  Colors.orangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Commission Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF123F4A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline_rounded,
                        color: Colors.orangeAccent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Commission Information',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Commission is auto-deducted at a flat 10% rate from the professional\'s wallet balance upon successful completion of booking payments.',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumStatCard(
      String title, String value, IconData icon, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF123F4A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalsTab(AdminProvider adminProv) {
    final list = adminProv.professionals;
    if (list.isEmpty) {
      return const Center(
          child: Text('No professionals registered',
              style: TextStyle(color: Colors.white)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        final serviceTypesList = p['serviceTypes'] ?? [];
        final serviceTypesString = serviceTypesList is List
            ? serviceTypesList.join(', ')
            : serviceTypesList.toString();

        return Card(
          color: const Color(0xFF123F4A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    (p['displayName'] ?? 'P').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['displayName'] ?? 'Professional',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(p['email'] ?? '',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 13)),
                      Text(p['phoneNumber'] ?? '',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          'Services: $serviceTypesString',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber[600], size: 18),
                          const SizedBox(width: 4),
                          Text('${p['rating'] ?? 0.0}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Icon(Icons.done_all_rounded,
                              color: Colors.greenAccent, size: 18),
                          const SizedBox(width: 4),
                          Text('${p['totalJobs'] ?? 0} Completed Jobs',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _editProfessional(
                        Map<String, dynamic>.from(p as Map),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Feedbacks',
                      icon: const Icon(Icons.reviews, color: Colors.amber),
                      onPressed: () => _showProfessionalReviews(
                        Map<String, dynamic>.from(p as Map),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent),
                      onPressed: () => _deleteUser(
                          p['uid'] ?? '', p['displayName'] ?? 'Professional'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomersTab(AdminProvider adminProv) {
    final list = adminProv.customers;
    if (list.isEmpty) {
      return const Center(
          child: Text('No customers registered',
              style: TextStyle(color: Colors.white)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final c = list[index];

        return Card(
          color: const Color(0xFF123F4A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.purple.withValues(alpha: 0.2),
                  child: Text(
                    (c['displayName'] ?? 'C').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['displayName'] ?? 'Customer',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(c['email'] ?? '',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 13)),
                      Text(c['phoneNumber'] ?? '',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(
                        'Total Bookings: ${c['totalBookings'] ?? 0}',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  onPressed: () => _deleteUser(
                      c['uid'] ?? '', c['displayName'] ?? 'Customer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookingsTab(AdminProvider adminProv) {
    final list = adminProv.bookings;
    if (list.isEmpty) {
      return const Center(
          child:
              Text('No bookings found', style: TextStyle(color: Colors.white)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final b = list[index];
        final date = b['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(b['createdAt'])
                .toString()
                .split('.')[0]
            : 'N/A';

        return Card(
          color: const Color(0xFF123F4A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Booking: ${b['bookingId']?.toString().substring(0, 8) ?? ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 13),
                          ),
                          _buildStatusBadge(b['status'] ?? ''),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          text: 'Customer: ',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 13),
                          children: [
                            TextSpan(
                              text: b['customerName'] ?? 'Customer',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          text: 'Professional: ',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 13),
                          children: [
                            TextSpan(
                              text: b['professionalName'] ?? 'Professional',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PKR ${b['agreedPrice'] ?? b['proposedPrice'] ?? 0}',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Text(
                            date,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  onPressed: () =>
                      _deleteBooking(b['bookingId'] ?? b['id'] ?? ''),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab(AdminProvider adminProv) {
    final list = adminProv.transactions;
    if (list.isEmpty) {
      return const Center(
          child: Text('No transactions recorded',
              style: TextStyle(color: Colors.white)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final tx = list[index];
        final date = tx['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(tx['createdAt'])
                .toString()
                .split('.')[0]
            : 'N/A';

        return Card(
          color: const Color(0xFF123F4A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tx ID: ${tx['transactionId'] ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontSize: 13),
                    ),
                    Text(
                      date,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const Divider(color: Colors.grey, height: 20),
                Text(
                  'Professional: ${tx['professionalName'] ?? 'Professional'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Booking ID: ${tx['bookingId'] ?? ''}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Paid by Customer',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                        Text('PKR ${tx['amount'] ?? 0}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Commission Deducted (10%)',
                            style: TextStyle(
                                color: Colors.orangeAccent, fontSize: 12)),
                        Text('PKR ${tx['commission'] ?? 0}',
                            style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'completed':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green;
        break;
      case 'cancelled':
      case 'rejected':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red;
        break;
      case 'confirmed':
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue;
        break;
      default:
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
