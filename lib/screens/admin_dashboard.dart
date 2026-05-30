import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_logo.dart';

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
              backgroundColor: AppColors.success),
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
              backgroundColor: AppColors.success),
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
            backgroundColor: AppColors.success,
          ),
        );
        _refreshData();
      }
    }
  }

  Future<void> _addAdminUser(String role) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final servicesCtrl = TextEditingController();
    final customCtrl = TextEditingController();
    final expCtrl = TextEditingController(text: '0');
    final rateCtrl = TextEditingController(text: '0');
    final addressCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          role == 'professional' ? 'Add Professional' : 'Add Customer',
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _adminField(nameCtrl, 'Name'),
                const SizedBox(height: 10),
                _adminField(phoneCtrl, 'Phone'),
                const SizedBox(height: 10),
                _adminField(emailCtrl, 'Email'),
                if (role == 'professional') ...[
                  const SizedBox(height: 10),
                  _adminField(servicesCtrl, 'Services comma separated'),
                  const SizedBox(height: 10),
                  _adminField(customCtrl, 'Custom services comma separated'),
                  const SizedBox(height: 10),
                  _adminField(expCtrl, 'Experience Years',
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  _adminField(rateCtrl, 'Hourly Rate',
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  _adminField(addressCtrl, 'Address'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final success =
          await Provider.of<AdminProvider>(context, listen: false).createUser({
        'role': role,
        'displayName': nameCtrl.text.trim(),
        'phoneNumber': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        if (role == 'professional') ...{
          'serviceTypes': servicesCtrl.text.trim(),
          'customServices': customCtrl.text.trim(),
          'experienceYears': int.tryParse(expCtrl.text.trim()) ?? 0,
          'hourlyRate': double.tryParse(rateCtrl.text.trim()) ?? 0,
          'address': addressCtrl.text.trim(),
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '${role == 'professional' ? 'Professional' : 'Customer'} added'
                : Provider.of<AdminProvider>(context, listen: false).error ??
                    'Add failed'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    servicesCtrl.dispose();
    customCtrl.dispose();
    expCtrl.dispose();
    rateCtrl.dispose();
    addressCtrl.dispose();
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
    final services = p['serviceTypes'] ?? p['services'] ?? [];
    final customServices = p['customServices'] ?? [];
    final servicesCtrl = TextEditingController(
        text: services is List ? services.join(', ') : services.toString());
    final customCtrl = TextEditingController(
        text: customServices is List
            ? customServices.join(', ')
            : customServices.toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Edit Professional',
            style: TextStyle(color: AppColors.textPrimary)),
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
              const SizedBox(height: 10),
              _adminField(servicesCtrl, 'Services comma separated'),
              const SizedBox(height: 10),
              _adminField(customCtrl, 'Custom services comma separated'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
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
        'serviceTypes': servicesCtrl.text.trim(),
        'customServices': customCtrl.text.trim(),
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
    servicesCtrl.dispose();
    customCtrl.dispose();
  }

  Widget _adminField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceLight,
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  String _initial(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return (text.isEmpty ? fallback : text).substring(0, 1).toUpperCase();
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 34, padding: 2, shadow: false),
            SizedBox(width: 10),
            Text('Admin Console',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'Add User',
            onSelected: _addAdminUser,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'professional',
                child: Text('Add Professional'),
              ),
              PopupMenuItem(
                value: 'customer',
                child: Text('Add Customer'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshData,
          ),
          IconButton(
            icon:
                const Icon(Icons.delete_sweep_rounded, color: AppColors.accent),
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Stats'),
            Tab(icon: Icon(Icons.engineering_rounded), text: 'Professionals'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Customers'),
            Tab(icon: Icon(Icons.book_online_rounded), text: 'Bookings'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Transactions'),
          ],
        ),
      ),
      body: adminProv.isLoading && !adminProv.hasAnyData
          ? _adminLoadingState()
          : adminProv.error != null && !adminProv.hasAnyData
              ? _adminRetryState(adminProv.error!)
              : Column(
                  children: [
                    if (adminProv.error != null)
                      _adminWarningBanner(adminProv.error!),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStatsTab(adminProv),
                          _buildProfessionalsTab(adminProv),
                          _buildCustomersTab(adminProv),
                          _buildBookingsTab(adminProv),
                          _buildTransactionsTab(adminProv),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _adminLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text(
            'Opening admin panel...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminRetryState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 90, padding: 6),
            const SizedBox(height: 18),
            const Text(
              'Admin data is still loading',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminWarningBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: _refreshData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(AdminProvider adminProv) {
    final stats = adminProv.stats;
    if (stats == null) {
      return const Center(
          child: Text('No stats available',
              style: TextStyle(color: AppColors.textPrimary)));
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
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Realtime insights and financial commission status.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
                  AppColors.primaryLight,
                ),
                _buildPremiumStatCard(
                  'Total Customers',
                  stats['totalCustomers']?.toString() ?? '0',
                  Icons.people_alt_rounded,
                  AppColors.accent,
                ),
                _buildPremiumStatCard(
                  'Completed Jobs',
                  stats['totalCompletedJobs']?.toString() ?? '0',
                  Icons.task_alt_rounded,
                  AppColors.success,
                ),
                _buildPremiumStatCard(
                  'Commission Earned',
                  'PKR ${stats['totalCommission'] ?? 0}',
                  Icons.payments_rounded,
                  AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Commission Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline_rounded,
                        color: AppColors.accent),
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
                              TextStyle(fontSize: 13, color: Color(0xFFDCE9D8)),
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
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryLight, width: 1.2),
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
                color: const Color(0xFFC7D8C4),
                fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _emptyAdminState(
    String message,
    IconData icon,
    VoidCallback onAdd,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 88, padding: 6),
            const SizedBox(height: 18),
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add New'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalsTab(AdminProvider adminProv) {
    final list = adminProv.professionals;
    if (list.isEmpty) {
      return _emptyAdminState(
        'No professionals registered',
        Icons.engineering_rounded,
        () => _addAdminUser('professional'),
      );
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
          color: AppColors.primaryDark,
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
                    _initial(p['displayName'], 'P'),
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
                              color: AppColors.success, size: 18),
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
      return _emptyAdminState(
        'No customers registered',
        Icons.people_alt_rounded,
        () => _addAdminUser('customer'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final c = list[index];

        return Card(
          color: AppColors.primaryDark,
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
                  backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                  child: Text(
                    _initial(c['displayName'], 'C'),
                    style: const TextStyle(
                        color: AppColors.accent,
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
                            color: AppColors.accent,
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
          child: Text('No bookings found',
              style: TextStyle(color: AppColors.textPrimary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final b = list[index];
        final bookingIdText = (b['bookingId'] ?? b['id'] ?? '').toString();
        final shortBookingId = bookingIdText.length > 8
            ? bookingIdText.substring(0, 8)
            : bookingIdText;
        final date = b['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(b['createdAt'])
                .toString()
                .split('.')[0]
            : 'N/A';

        return Card(
          color: AppColors.primaryDark,
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
                            'Booking: $shortBookingId',
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
                                color: AppColors.accent,
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
              style: TextStyle(color: AppColors.textPrimary)));
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
          color: AppColors.primaryDark,
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
                                color: AppColors.accent, fontSize: 12)),
                        Text('PKR ${tx['commission'] ?? 0}',
                            style: const TextStyle(
                                color: AppColors.accent,
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
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        break;
      case 'cancelled':
      case 'rejected':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red;
        break;
      case 'confirmed':
        bg = AppColors.primaryLight.withValues(alpha: 0.15);
        fg = AppColors.primaryLight;
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
