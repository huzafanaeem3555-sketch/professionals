import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../utils/constants.dart';
import '../utils/contact_actions.dart';
import '../widgets/app_logo.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _professionalFilter = 'all';
  String _customerFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
        backgroundColor: Colors.white,
        title: const Text('Delete User',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
            'Are you sure you want to delete user "$name"? Customer data, bookings, payments, and transactions will be removed. Professional accounts are preserved and deactivated instead of deleted.',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
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

  Future<void> _verifyUser(
    String uid,
    bool verified, {
    bool? isActive,
  }) async {
    final success = await Provider.of<AdminProvider>(context, listen: false)
        .verifyUser(uid, verified: verified, isActive: isActive);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? (verified
                ? (isActive == false
                    ? 'Account verified and inactive'
                    : 'Account verified')
                : 'Account set to pending')
            : Provider.of<AdminProvider>(context, listen: false).error ??
                'Verification update failed'),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  Widget _adminUserActions(Map<String, dynamic> user) {
    final uid = user['uid']?.toString() ?? '';
    final status = user['verificationStatus']?.toString().toLowerCase() ?? '';
    final verified = status == 'verified';
    final active = user['isActive'] != false;
    if (uid.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        OutlinedButton.icon(
          icon: Icon(verified ? Icons.undo_rounded : Icons.verified_user),
          label: Text(verified ? 'Set Pending' : 'Verify'),
          style: OutlinedButton.styleFrom(
            foregroundColor: verified ? AppColors.warning : AppColors.success,
            side: BorderSide(
              color: verified ? AppColors.warning : AppColors.success,
            ),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: () => _verifyUser(
            uid,
            !verified,
            isActive: !verified ? true : false,
          ),
        ),
        OutlinedButton.icon(
          icon: Icon(active ? Icons.block_rounded : Icons.check_circle_outline),
          label: Text(active ? 'Deactivate' : 'Activate'),
          style: OutlinedButton.styleFrom(
            foregroundColor: active ? Colors.redAccent : AppColors.success,
            side: BorderSide(
              color: active ? Colors.redAccent : AppColors.success,
            ),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: () => _verifyUser(
            uid,
            active ? verified : true,
            isActive: !active,
          ),
        ),
      ],
    );
  }

  Widget _adminTextAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.65)),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }

  Future<void> _deleteBooking(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Booking',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Are you sure you want to delete this booking and its associated payments/transactions?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
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
        backgroundColor: Colors.white,
        title: const Text('Clear App Data',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will delete all customers, professionals, bookings, transactions, chats and payments. Admin user will remain.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
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
    final genderCtrl = TextEditingController(text: 'male');
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
                const SizedBox(height: 10),
                _adminField(genderCtrl, 'Gender male/female'),
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
        'gender': genderCtrl.text.trim(),
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
    genderCtrl.dispose();
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
    final genderCtrl =
        TextEditingController(text: p['gender']?.toString() ?? 'male');
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
              const SizedBox(height: 10),
              _adminField(genderCtrl, 'Gender male/female'),
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
        'gender': genderCtrl.text.trim(),
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
    genderCtrl.dispose();
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

  String _flatten(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return value.values.map(_flatten).join(' ');
    }
    if (value is Iterable) {
      return value.map(_flatten).join(' ');
    }
    return value.toString();
  }

  String _normalizedGender(dynamic value) {
    return value?.toString().toLowerCase().trim() == 'female'
        ? 'female'
        : 'male';
  }

  String _normalizedStatus(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? '';
    return status.isEmpty ? 'verified' : status;
  }

  bool _matchesSearch(Map<String, dynamic> item, String query) {
    if (query.isEmpty) return true;
    final haystack = [
      item['uid'],
      item['id'],
      item['displayName'],
      item['name'],
      item['email'],
      item['phone'],
      item['phoneNumber'],
      item['gender'],
      item['verificationStatus'],
      item['status'],
      item['role'],
      item['serviceTypes'],
      item['services'],
      item['customServices'],
      item['address'],
      item['location'],
      item['bookingId'],
      item['transactionId'],
      item['customerName'],
      item['professionalName'],
    ].map(_flatten).join(' ').toLowerCase();
    return haystack.contains(query);
  }

  List<Map<String, dynamic>> _filteredProfessionals(AdminProvider adminProv) {
    final query = _searchQuery.trim().toLowerCase();
    return adminProv.professionals
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) {
      final gender = _normalizedGender(item['gender']);
      final status = _normalizedStatus(item['verificationStatus']);

      switch (_professionalFilter) {
        case 'female':
          if (gender != 'female') return false;
          break;
        case 'male':
          if (gender != 'male') return false;
          break;
        case 'pending':
          if (status == 'verified') return false;
          break;
        case 'verified':
          if (status != 'verified') return false;
          break;
      }

      return _matchesSearch(item, query);
    }).toList();
  }

  List<Map<String, dynamic>> _filteredCustomers(AdminProvider adminProv) {
    final query = _searchQuery.trim().toLowerCase();
    return adminProv.customers
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) {
      final gender = _normalizedGender(item['gender']);
      final status = _normalizedStatus(item['verificationStatus']);

      switch (_customerFilter) {
        case 'female':
          if (gender != 'female') return false;
          break;
        case 'male':
          if (gender != 'male') return false;
          break;
        case 'pending':
          if (status == 'verified') return false;
          break;
        case 'verified':
          if (status != 'verified') return false;
          break;
      }

      return _matchesSearch(item, query);
    }).toList();
  }

  List<Map<String, dynamic>> _filteredBookings(AdminProvider adminProv) {
    final query = _searchQuery.trim().toLowerCase();
    return adminProv.bookings
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => _matchesSearch(item, query))
        .toList();
  }

  List<Map<String, dynamic>> _filteredTransactions(AdminProvider adminProv) {
    final query = _searchQuery.trim().toLowerCase();
    return adminProv.transactions
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => _matchesSearch(item, query))
        .toList();
  }

  List<Map<String, dynamic>> _filteredComplaints(AdminProvider adminProv) {
    final query = _searchQuery.trim().toLowerCase();
    return adminProv.complaints
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) =>
            query.isEmpty || _flatten(item).toLowerCase().contains(query))
        .toList();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _professionalFilter = 'all';
      _customerFilter = 'all';
    });
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
        backgroundColor: Colors.white,
        title: const Text('Feedbacks',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: reviews.isEmpty
              ? const Text('No feedback yet',
                  style: TextStyle(color: AppColors.textSecondary))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index] as Map;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${review['customerName'] ?? 'Customer'} - ${review['rating'] ?? 0} star',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        review['review']?.toString() ?? '',
                        style: const TextStyle(color: AppColors.textSecondary),
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

  Widget _buildAdminSearchPanel() {
    final tabIndex = _tabController.index;
    final showProfessionalFilters = tabIndex == 1;
    final showCustomerFilters = tabIndex == 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search users, status, phone, service or booking ID',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _resetFilters,
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          if (showProfessionalFilters || showCustomerFilters) ...[
            const SizedBox(height: 10),
            _buildVerificationFilters(
              title: showProfessionalFilters
                  ? 'Professional filters'
                  : 'Customer filters',
              current: showProfessionalFilters
                  ? _professionalFilter
                  : _customerFilter,
              onChanged: (value) {
                setState(() {
                  if (showProfessionalFilters) {
                    _professionalFilter = value;
                  } else {
                    _customerFilter = value;
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationFilters({
    required String title,
    required String current,
    required ValueChanged<String> onChanged,
  }) {
    final filters = <Map<String, String>>[
      {'label': 'All', 'value': 'all'},
      {'label': 'Pending', 'value': 'pending'},
      {'label': 'Verified', 'value': 'verified'},
      {'label': 'Female', 'value': 'female'},
      {'label': 'Male', 'value': 'male'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((filter) {
            final value = filter['value']!;
            final label = filter['label']!;
            final selected = current == value;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => onChanged(value),
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: Colors.white,
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Admin Console',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
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
            Tab(icon: Icon(Icons.report_problem_rounded), text: 'Complaints'),
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
                    _buildAdminSearchPanel(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStatsTab(adminProv),
                          _buildProfessionalsTab(adminProv),
                          _buildCustomersTab(adminProv),
                          _buildBookingsTab(adminProv),
                          _buildComplaintsTab(adminProv),
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

            _buildServiceUsagePanel(stats['serviceUsage']),
            const SizedBox(height: 24),
            _buildCleanupControl(adminProv),
            const SizedBox(height: 24),

            // Commission Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Commission is auto-deducted at a flat 10% rate from the professional\'s wallet balance upon successful completion of booking payments.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
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

  Widget _buildCleanupControl(AdminProvider adminProv) {
    final settings = adminProv.marketplace['cleanupSettings'] is Map
        ? Map<String, dynamic>.from(adminProv.marketplace['cleanupSettings'])
        : <String, dynamic>{};
    final current = int.tryParse(settings['hours']?.toString() ?? '') ?? 5;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Lead Auto Cleanup',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Professional ke customers/leads kitne hours baad auto remove hon.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [4, 5, 24].map((hours) {
              final selected = current == hours;
              return ChoiceChip(
                selected: selected,
                label: Text('${hours}h'),
                onSelected: (_) => adminProv
                    .updateCleanupHours(hours)
                    .then((_) => _refreshData()),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceUsagePanel(dynamic rawUsage) {
    final usage = rawUsage is List
        ? rawUsage
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    if (usage.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Text(
          'No service usage data yet.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Most Used Services',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Sorted by searches, contacts, bookings, and available professionals.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ...usage.take(8).map((item) {
            final label = _shortText(item['label'], fallback: 'Service');
            final search = _shortText(item['searchCount'], fallback: '0');
            final contacts = _shortText(item['contactCount'], fallback: '0');
            final bookings = _shortText(item['bookingCount'], fallback: '0');
            final score = _shortText(item['score'], fallback: '0');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _miniMetric('Score', score),
                        _miniMetric('Search', search),
                        _miniMetric('Contact', contacts),
                        _miniMetric('Book', bookings),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatCard(
      String title, String value, IconData icon, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
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

  Widget _emptyFilteredState(
    String message,
    IconData icon,
    VoidCallback onClear,
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
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _shortText(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Widget _detailRow(String label, dynamic value) {
    final text = _flatten(value).trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUserDetails(
    Map<String, dynamic> user, {
    required String type,
  }) async {
    final isProfessional = type == 'professional';
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Text(
                        _initial(
                            user['displayName'], isProfessional ? 'P' : 'C'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shortText(
                              user['displayName'],
                              fallback:
                                  isProfessional ? 'Professional' : 'Customer',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isProfessional
                                ? 'Professional profile'
                                : 'Customer profile',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: 'Close details',
                      child: IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metaChip(
                            'Gender: ${_shortText(user['gender'], fallback: 'male')}',
                            isProfessional
                                ? AppColors.primaryLight
                                : AppColors.accent,
                          ),
                          _metaChip(
                            'Status: ${_shortText(user['verificationStatus'], fallback: 'verified')}',
                            user['verificationStatus'] == 'verified'
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          _metaChip(
                            'Active: ${user['isActive'] != false ? 'Yes' : 'No'}',
                            user['isActive'] != false
                                ? AppColors.success
                                : Colors.redAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _detailRow('UID', user['uid']),
                      _detailRow('Name', user['displayName'] ?? user['name']),
                      _detailRow('Email', user['email']),
                      _detailRow('Phone', user['phoneNumber'] ?? user['phone']),
                      if (isProfessional) ...[
                        _detailRow('Services',
                            user['serviceTypes'] ?? user['services']),
                        _detailRow('Custom', user['customServices']),
                        _detailRow('Experience', user['experienceYears']),
                        _detailRow('Rating', user['rating']),
                        _detailRow('Jobs', user['totalJobs']),
                        _detailRow(
                            'Location', user['location'] ?? user['address']),
                      ] else ...[
                        _detailRow('Bookings', user['totalBookings']),
                        _detailRow('Address', user['address']),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _adminUserActions(user),
                    if (isProfessional)
                      Tooltip(
                        message: 'Edit professional profile fields',
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editProfessional(user);
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminSummaryCard({
    required Map<String, dynamic> user,
    required String type,
    required Color accent,
    required List<Widget> actions,
    String? subtitle,
  }) {
    final isProfessional = type == 'professional';
    final name = _shortText(user['displayName'],
        fallback: isProfessional ? 'Professional' : 'Customer');
    final phone =
        _shortText(user['phoneNumber'] ?? user['phone'], fallback: '');
    final status = _shortText(user['verificationStatus'], fallback: 'verified');
    final active = user['isActive'] != false;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showUserDetails(user, type: type),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 430;
              final actionWrap = Wrap(
                alignment: WrapAlignment.end,
                spacing: 2,
                runSpacing: 2,
                children: actions,
              );
              final info = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accent.withValues(alpha: 0.14),
                    child: Text(
                      _initial(name, isProfessional ? 'P' : 'C'),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          phone.isNotEmpty
                              ? phone
                              : _shortText(user['email'],
                                  fallback: 'No contact'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _metaChip(
                              _shortText(user['gender'], fallback: 'male'),
                              accent,
                            ),
                            _metaChip(
                              status,
                              status == 'verified'
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            _metaChip(
                              active ? 'active' : 'inactive',
                              active ? AppColors.success : Colors.redAccent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    const SizedBox(height: 8),
                    actionWrap,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 8),
                  actionWrap,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalsTab(AdminProvider adminProv) {
    final list = _filteredProfessionals(adminProv);
    if (adminProv.professionals.isEmpty) {
      return _emptyAdminState(
        'No professionals registered',
        Icons.engineering_rounded,
        () => _addAdminUser('professional'),
      );
    }
    if (list.isEmpty) {
      return _emptyFilteredState(
        'No professionals match the selected filters',
        Icons.manage_search_rounded,
        _resetFilters,
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

        return _adminSummaryCard(
          user: p,
          type: 'professional',
          accent: AppColors.primary,
          subtitle: serviceTypesString.isEmpty ? null : serviceTypesString,
          actions: [
            _adminUserActions(p),
            _adminTextAction(
              icon: Icons.edit,
              label: 'Edit',
              color: AppColors.primary,
              onPressed: () => _editProfessional(p),
            ),
            _adminTextAction(
              icon: Icons.reviews,
              label: 'Reviews',
              color: Colors.amber.shade700,
              onPressed: () => _showProfessionalReviews(p),
            ),
            _adminTextAction(
              icon: Icons.info_outline,
              label: 'Details',
              color: AppColors.primary,
              onPressed: () => _showUserDetails(p, type: 'professional'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomersTab(AdminProvider adminProv) {
    final list = _filteredCustomers(adminProv);
    if (adminProv.customers.isEmpty) {
      return _emptyAdminState(
        'No customers registered',
        Icons.people_alt_rounded,
        () => _addAdminUser('customer'),
      );
    }
    if (list.isEmpty) {
      return _emptyFilteredState(
        'No customers match the selected filters',
        Icons.manage_search_rounded,
        _resetFilters,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final c = list[index];

        return _adminSummaryCard(
          user: c,
          type: 'customer',
          accent: AppColors.accent,
          subtitle: 'Bookings: ${c['totalBookings'] ?? 0}',
          actions: [
            _adminUserActions(c),
            _adminTextAction(
              icon: Icons.info_outline,
              label: 'Details',
              color: AppColors.primary,
              onPressed: () => _showUserDetails(c, type: 'customer'),
            ),
            _adminTextAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: Colors.redAccent,
              onPressed: () => _deleteUser(
                c['uid'] ?? '',
                c['displayName'] ?? 'Customer',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBookingsTab(AdminProvider adminProv) {
    final list = _filteredBookings(adminProv);
    if (adminProv.bookings.isEmpty) {
      return const Center(
          child: Text('No bookings found',
              style: TextStyle(color: AppColors.textPrimary)));
    }
    if (list.isEmpty) {
      return _emptyFilteredState(
        'No bookings match the current search',
        Icons.manage_search_rounded,
        _resetFilters,
      );
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
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.divider)),
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
                                color: AppColors.textSecondary,
                                fontSize: 13),
                          ),
                          _buildStatusBadge(b['status'] ?? ''),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          text: 'Customer: ',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                          children: [
                            TextSpan(
                              text: b['customerName'] ?? 'Customer',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
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
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                          children: [
                            TextSpan(
                              text: b['professionalName'] ?? 'Professional',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
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
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 12),
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

  Widget _buildComplaintsTab(AdminProvider adminProv) {
    final list = _filteredComplaints(adminProv);
    if (adminProv.complaints.isEmpty) {
      return const Center(
        child: Text(
          'No customer complaints yet',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      );
    }
    if (list.isEmpty) {
      return _emptyFilteredState(
        'No complaints match the current search',
        Icons.manage_search_rounded,
        _resetFilters,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final c = list[index];
        final id = c['complaintId']?.toString() ?? c['_key']?.toString() ?? '';
        final proId = c['professionalId']?.toString() ?? '';
        final proPhone = c['professionalPhone']?.toString() ?? '';
        final reason = c['reason']?.toString() ?? '';
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.divider),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c['professionalName']?.toString() ?? 'Professional',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _buildStatusBadge(c['status']?.toString() ?? 'open'),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  'Pro ID: $proId',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customer: ${c['customerName'] ?? 'Customer'} (${c['customerPhone'] ?? ''})',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Text(
                  reason,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: proPhone.isEmpty
                          ? null
                          : () => launchContactUri(contactUriFor(
                                method: ContactMethod.whatsapp,
                                phoneNumber: proPhone,
                                message:
                                    'HirePro admin: customer complaint received. Please respond about complaint ID $id.',
                              )),
                      icon: const Icon(Icons.chat_rounded),
                      label: const Text('WhatsApp Pro'),
                    ),
                    OutlinedButton.icon(
                      onPressed: proId.isEmpty
                          ? null
                          : () => _verifyUser(proId, true, isActive: false),
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Block Pro'),
                    ),
                    ElevatedButton.icon(
                      onPressed: id.isEmpty
                          ? null
                          : () => adminProv.updateComplaint(
                                id,
                                {'status': 'resolved'},
                              ),
                      icon: const Icon(Icons.done_rounded),
                      label: const Text('Resolve'),
                    ),
                    IconButton(
                      tooltip: 'Delete complaint',
                      onPressed: id.isEmpty
                          ? null
                          : () => adminProv.deleteComplaint(id),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error),
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

  Widget _buildTransactionsTab(AdminProvider adminProv) {
    final list = _filteredTransactions(adminProv);
    if (adminProv.transactions.isEmpty) {
      return const Center(
          child: Text('No transactions recorded',
              style: TextStyle(color: AppColors.textPrimary)));
    }
    if (list.isEmpty) {
      return _emptyFilteredState(
        'No transactions match the current search',
        Icons.manage_search_rounded,
        _resetFilters,
      );
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
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.divider)),
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
                          color: AppColors.textSecondary,
                          fontSize: 13),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(color: AppColors.divider, height: 20),
                Text(
                  'Professional: ${tx['professionalName'] ?? 'Professional'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Booking ID: ${tx['bookingId'] ?? ''}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Paid by Customer',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        Text('PKR ${tx['amount'] ?? 0}',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
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
