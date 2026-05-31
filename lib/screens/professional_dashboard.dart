import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/contact_actions.dart';
import '../widgets/map_card.dart';
import '../widgets/notification_bell.dart';

class ProfessionalDashboard extends StatefulWidget {
  const ProfessionalDashboard({super.key});

  @override
  State<ProfessionalDashboard> createState() => _ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends State<ProfessionalDashboard> {
  final _firebase = FirebaseService();
  final _db = FirebaseDatabase.instance.ref();

  String? _phone;
  String _name = '';
  String _gender = 'male';
  String _photoURL = '';
  bool _isAvailable = true;
  bool _loadingProfile = true;
  StreamSubscription<DatabaseEvent>? _bookingsSub;
  StreamSubscription<DatabaseEvent>? _profileSub;
  List<Map<String, dynamic>> _leads = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _bookingsSub?.cancel();
    await _profileSub?.cancel();
    final uid =
        await StorageService.getUid() ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    _gender =
        (await StorageService.getGender() ?? 'male').toLowerCase() == 'female'
            ? 'female'
            : 'male';

    _profileSub = _db.child('professionals/$uid').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null && mounted) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _name = data['name']?.toString() ?? '';
          _phone = data['phone']?.toString() ??
              data['phoneNumber']?.toString() ??
              '';
          _gender = data['gender']?.toString().toLowerCase() == 'female'
              ? 'female'
              : 'male';
          _photoURL = data['photoURL']?.toString() ?? '';
          _isAvailable = data['isAvailable'] ?? true;
          _loadingProfile = false;
        });
      } else if (mounted) {
        setState(() => _loadingProfile = false);
      }
    });

    _bookingsSub = _db
        .child('professionalContactLeads/$uid')
        .onValue
        .listen((event) async {
      final list = <Map<String, dynamic>>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final map = Map<String, dynamic>.from(event.snapshot.value as Map);
        for (final entry in map.entries) {
          final id = entry.key;
          final value = entry.value;
          final b = Map<String, dynamic>.from(value as Map);
          final expiresAt = _toInt(b['expiresAt']);
          if (expiresAt > 0 && expiresAt <= now) {
            unawaited(_db.child('professionalContactLeads/$uid/$id').remove());
            continue;
          }
          final customerGender =
              b['customerGender']?.toString().toLowerCase() == 'female'
                  ? 'female'
                  : 'male';
          if (customerGender != _gender) {
            continue;
          }
          b['leadId'] = id;
          list.add(b);
        }
        list.sort(
            (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      }
      if (mounted) setState(() => _leads = list);
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _toggleAvailability(bool value) async {
    final uid =
        await StorageService.getUid() ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    setState(() => _isAvailable = value);
    await _firebase.updateAvailability(uid, value);
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, inner) => [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
              title: const Text(
                'Dashboard',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              actions: [
                const NotificationBell(),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Sign Out',
                  onPressed: _signOut,
                ),
              ],
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(icon: Icon(Icons.dashboard_rounded), text: 'Home'),
                  Tab(icon: Icon(Icons.people_alt_rounded), text: 'Customers'),
                  Tab(icon: Icon(Icons.person_rounded), text: 'Profile'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _buildHomeTab(),
              _buildLeadsList(showAll: true),
              _buildProfileTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 2),
                  image: _photoURL.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_photoURL),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Center(
                  child: _photoURL.isEmpty
                      ? Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : 'P',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.isNotEmpty ? _name : 'Professional',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    if (_phone != null && _phone!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(_phone!,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: _isAvailable
                                    ? const Color(0xFF4ADE80)
                                    : Colors.grey,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(_isAvailable ? 'Online' : 'Offline',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                              value: _isAvailable,
                              onChanged: _toggleAvailability,
                              activeColor: const Color(0xFF4ADE80)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _init,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Customers',
                  value: '${_leads.length}',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Status',
                  value: _isAvailable ? 'Online' : 'Offline',
                  icon: Icons.circle,
                  color: _isAvailable ? AppColors.success : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Customers',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => DefaultTabController.of(context).animateTo(1),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_leads.isEmpty)
            const _EmptyContacts()
          else
            ..._leads.take(3).map(
                  (lead) => _LeadCard(
                    lead: lead,
                    onDelete: () =>
                        _deleteLead(lead['leadId']?.toString() ?? ''),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                backgroundImage:
                    _photoURL.isNotEmpty ? NetworkImage(_photoURL) : null,
                child: _photoURL.isEmpty
                    ? Text(
                        _name.isNotEmpty ? _name[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                _name.isNotEmpty ? _name : 'Professional',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_phone != null && _phone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _phone!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null && uid.isNotEmpty) {
                          Navigator.pushNamed(
                            context,
                            '/professional-profile',
                            arguments: {'uid': uid},
                          );
                        }
                      },
                      icon: const Icon(Icons.visibility_rounded),
                      label: const FittedBox(child: Text('View Profile')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/professional-setup'),
                      icon: const Icon(Icons.edit_rounded),
                      label: const FittedBox(child: Text('Edit Profile')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await StorageService.clearRole();
                  if (!mounted) return;
                  navigator.pushReplacementNamed('/role-selection');
                },
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Change Role'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeadsList({bool showAll = false}) {
    if (_leads.isEmpty) {
      return const Center(child: _EmptyContacts());
    }
    final leads = showAll ? _leads : _leads.take(3).toList();
    return RefreshIndicator(
      onRefresh: _init,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: leads.length,
        itemBuilder: (ctx, i) => _LeadCard(
          lead: leads[i],
          onDelete: () => _deleteLead(leads[i]['leadId']?.toString() ?? ''),
        ),
      ),
    );
  }

  Future<void> _deleteLead(String leadId) async {
    final uid =
        await StorageService.getUid() ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || leadId.isEmpty) return;
    await _db.child('professionalContactLeads/$uid/$leadId').remove();
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final VoidCallback onDelete;
  const _LeadCard({required this.lead, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final service = lead['serviceType']?.toString().isNotEmpty == true
        ? lead['serviceType'].toString()
        : 'Direct Contact';
    final address = lead['customerAddress']?.toString().isNotEmpty == true
        ? lead['customerAddress'].toString()
        : lead['address']?.toString() ?? '';
    final phone = lead['customerPhone']?.toString() ?? '';
    final name = lead['customerName']?.toString() ?? 'Customer';
    final desc =
        lead['body']?.toString() ?? lead['description']?.toString() ?? '';
    final location = lead['customerLocation'];
    double? lat;
    double? lng;
    if (location is Map) {
      final rawLat = location['lat'];
      final rawLng = location['lng'];
      if (rawLat is num && rawLng is num) {
        lat = rawLat.toDouble();
        lng = rawLng.toDouble();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(
                  bottom:
                      BorderSide(color: AppColors.primary.withOpacity(0.08))),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        service.replaceAll('_', ' '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.error),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (lat != null && lng != null && (lat != 0 || lng != 0)) ...[
                  MapCard(
                    lat: lat,
                    lng: lng,
                    title: '$name Location',
                    subtitle:
                        address.isNotEmpty ? address : 'Customer location',
                    height: 160,
                  ),
                  const SizedBox(height: 8),
                ],
                if (phone.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.phone,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (desc.isNotEmpty) ...[
                  Text(
                    '"$desc"',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: phone.isNotEmpty
                            ? () async {
                                final uri = contactUriFor(
                                    method: ContactMethod.call,
                                    phoneNumber: phone);
                                await launchContactUri(uri);
                              }
                            : null,
                        icon: const Icon(Icons.call,
                            size: 18, color: Colors.white),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Call',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: phone.isNotEmpty
                            ? () async {
                                final uri = contactUriFor(
                                    method: ContactMethod.whatsapp,
                                    phoneNumber: phone,
                                    message:
                                        'Assalam-o-Alaikum, I received your request on Hirepro.');
                                await launchContactUri(uri);
                              }
                            : null,
                        icon: const Icon(Icons.message,
                            size: 18, color: Colors.white),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'WhatsApp',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.people_outline, size: 64, color: AppColors.textLight),
          SizedBox(height: 16),
          Text(
            'No Recent Contacts',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Customers who tap WhatsApp or Call will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
