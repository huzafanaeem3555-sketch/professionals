import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/professional_model.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../utils/helpers.dart';
import '../utils/contact_actions.dart';
import '../screens/my_bookings_screen.dart';
import '../widgets/notification_bell.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  static const double _maxRadiusKm = 100;
  final _firebase = FirebaseService();
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  double _lat = 0;
  double _lng = 0;
  List<ProfessionalModel> _all = [];
  List<ProfessionalModel> _filtered = [];
  List<_SearchSuggestion> _suggestions = [];
  int _activeBookingsCount = 0;
  String? _filterService;
  String _myArea = '';
  bool _loading = true;
  bool _booking = false;
  String? _locationError;
  double _distanceFilterKm = 0;
  Map<String, String> _userDetails = {};
  String? _aiSuggestedService;
  Timer? _aiSuggestDebounce;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureCustomerPhone();
      await _load();
    });
  }

  @override
  void dispose() {
    _aiSuggestDebounce?.cancel();
    _searchCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _locationError = null;
    });

    final userDetailsFuture = StorageService.getUserDetails();
    final customerIdFuture = StorageService.getUid();
    final professionalsFuture = _firebase.getAllProfessionals();

    try {
      final pos = await LocationService()
          .getCurrentPosition(maxAttempts: 1)
          .timeout(const Duration(seconds: 8));
      _lat = pos.latitude;
      _lng = pos.longitude;
      _myArea = await LocationService()
          .getAddressFromCoordinates(_lat, _lng)
          .timeout(const Duration(seconds: 4), onTimeout: () => '');
    } catch (e) {
      _locationError =
          'Location unavailable. Enable GPS to sort professionals by distance.';
    }

    _userDetails = await userDetailsFuture;
    final customerId = await customerIdFuture ?? '';
    final bookingsFuture = _firebase.getBookingsForCustomer(customerId);

    var raw = await professionalsFuture;

    // Fallback to API if Firebase empty
    if (raw.isEmpty && _lat != 0) {
      final api = await ApiService().getNearbyProfessionals(
        lat: _lat,
        lng: _lng,
        radius: _maxRadiusKm,
      );
      if (api['success'] == true && api['data'] != null) {
        final data = api['data'];
        if (data is List) {
          raw = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (data is Map && data['professionals'] is List) {
          raw = (data['professionals'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    }

    // Build model list with distance. If location is unavailable, still show
    // live Firebase professionals so search never appears empty.
    final list = <ProfessionalModel>[];
    for (final p in raw) {
      final model = ProfessionalModel.fromJson(p);
      if (_lat == 0 || _lng == 0) {
        list.add(model);
        continue;
      }
      final dist = LocationService.haversineKm(
          _lat, _lng, model.location.lat, model.location.lng);
      list.add(model.copyWith(distance: dist));
    }
    list.sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));

    final bookings = await bookingsFuture;
    final activeCount = bookings
        .where((b) => [
              'pending',
              'pending_acceptance',
              'confirmed',
              'in_progress',
              'pending_customer_response',
            ].contains(b['status']))
        .length;

    if (mounted) {
      setState(() {
        _all = list;
        _activeBookingsCount = activeCount;
        _applyFilter();
        _buildSuggestions(_searchCtrl.text);
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  void _applyFilter() {
    var list = List<ProfessionalModel>.from(_all);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (_lat != 0 && _lng != 0 && _distanceFilterKm > 0) {
      list =
          list.where((p) => (p.distance ?? 999) <= _distanceFilterKm).toList();
    }
    if (_filterService != null && _filterService!.isNotEmpty) {
      list = list.where((p) {
        return p.allServices.any((service) =>
            _sameService(service, _filterService!) ||
            _matchesQuery(ServiceLabels.getName(service), _filterService!));
      }).toList();
    }
    if (q.isNotEmpty) {
      list = list.where((p) {
        return _professionalMatchesQuery(p, q);
      }).toList();

      int score(ProfessionalModel p) {
        var points = 0;
        final name = p.name.toLowerCase();
        final services = p.allServices.join(' ').toLowerCase();
        final address = p.address.toLowerCase();
        if (services.startsWith(q)) points += 120;
        if (services.contains(q)) points += 90;
        if (name.startsWith(q)) points += 80;
        if (name.contains(q)) points += 55;
        if (address.contains(q)) points += 20;
        if (p.isAvailable) points += 10;
        final distancePenalty = (p.distance ?? 999).clamp(0, 200).toInt();
        return points - distancePenalty;
      }

      list.sort((a, b) {
        final diff = score(b).compareTo(score(a));
        if (diff != 0) return diff;
        return (a.distance ?? 999).compareTo(b.distance ?? 999);
      });
    }
    _filtered = list;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _filterService = null;
      _buildSuggestions(value);
      _applyFilter();
    });
    _aiSuggestDebounce?.cancel();
    final q = value.trim();
    if (q.length < 4) {
      if (_aiSuggestedService != null) {
        setState(() => _aiSuggestedService = null);
      }
      return;
    }
    _aiSuggestDebounce = Timer(const Duration(milliseconds: 550), () async {
      final res = await _api.recommendService(q);
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final suggested = data['serviceType']?.toString();
        if (suggested != null && suggested.isNotEmpty) {
          setState(() => _aiSuggestedService = suggested);
        }
      }
    });
  }

  void _buildSuggestions(String value) {
    final q = value.trim().toLowerCase();
    if (q.isEmpty) {
      _suggestions = [];
      return;
    }

    final suggestions = <String, _SearchSuggestion>{};
    for (final pro in _all) {
      for (final service in pro.allServices) {
        final label = _displayServiceName(service);
        final searchBlob = '$service $label'.toLowerCase();
        if (_matchesQuery(searchBlob, q)) {
          suggestions.putIfAbsent(
            service.toLowerCase(),
            () => _SearchSuggestion(
              label: label,
              serviceKey: service,
              matchCount: _all
                  .where(
                      (p) => p.allServices.any((s) => _sameService(s, service)))
                  .length,
            ),
          );
        }
      }
      if (_matchesQuery(pro.name, q)) {
        suggestions.putIfAbsent(
          'pro:${pro.uid}',
          () => _SearchSuggestion(
            label: pro.name,
            professionalUid: pro.uid,
            matchCount: 1,
          ),
        );
      }
    }

    final list = suggestions.values.toList()
      ..sort((a, b) {
        final countDiff = b.matchCount.compareTo(a.matchCount);
        if (countDiff != 0) return countDiff;
        return a.label.compareTo(b.label);
      });
    _suggestions = list.take(8).toList();
  }

  void _selectSuggestion(_SearchSuggestion suggestion) {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchCtrl.text = suggestion.label;
      _searchCtrl.selection =
          TextSelection.collapsed(offset: suggestion.label.length);
      _filterService = suggestion.serviceKey;
      _suggestions = [];
      if (suggestion.professionalUid != null) {
        _filtered =
            _all.where((p) => p.uid == suggestion.professionalUid).toList();
      } else {
        _applyFilter();
      }
    });
  }

  bool _professionalMatchesQuery(ProfessionalModel p, String query) {
    if (_matchesQuery(p.name, query) || _matchesQuery(p.address, query)) {
      return true;
    }
    for (final service in p.allServices) {
      if (_matchesQuery(service, query) ||
          _matchesQuery(service.replaceAll('_', ' '), query) ||
          _matchesQuery(_displayServiceName(service), query)) {
        return true;
      }
    }
    return false;
  }

  bool _sameService(String a, String b) {
    final x = _normalizeSearchText(a);
    final y = _normalizeSearchText(b);
    return x == y || x.contains(y) || y.contains(x);
  }

  String _displayServiceName(String key) {
    final label = ServiceLabels.getName(key);
    return label == key ? key.replaceAll('_', ' ') : label;
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesQuery(String source, String query) {
    final s = _normalizeSearchText(source);
    final q = _normalizeSearchText(query);
    if (q.isEmpty) return false;
    if (s.contains(q)) return true;
    final words = s.split(RegExp(r'\s+'));
    final queryWords = q.split(RegExp(r'\s+'));
    for (final w in words) {
      for (final queryWord in queryWords) {
        if (queryWord.isEmpty) continue;
        if (w.startsWith(queryWord) || queryWord.startsWith(w)) {
          return true;
        }
        if (queryWord.length >= 3 && _editDistance(w, queryWord) <= 2) {
          return true;
        }
      }
    }
    return false;
  }

  int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _contactProfessional(
    ProfessionalModel pro, {
    required ContactMethod method,
  }) async {
    if (_booking) return;
    final customerPhone = await _ensureCustomerPhone(requiredForContact: true);
    if (customerPhone == null || customerPhone.isEmpty) return;
    final contactLocation = await _resolveCustomerContactLocation();
    final customerAddress = contactLocation['address'] as String;
    final customerLocation =
        Map<String, dynamic>.from(contactLocation['location'] as Map);
    if (pro.phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Professional phone number not available')),
      );
      return;
    }

    setState(() => _booking = true);
    try {
      final serviceType = _bestServiceForContact(pro);
      final customerId = await StorageService.getUid() ?? '';
      final customerName = _userDetails['name']?.trim().isNotEmpty == true
          ? _userDetails['name']!.trim()
          : 'Customer';
      var leadSaved = await _firebase.saveContactLead(
        professionalId: pro.uid,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        serviceType: serviceType,
        contactMethod: method.name,
        customerLocation: customerLocation,
      );
      if (!leadSaved) {
        final fallback = await _api.saveContactLeadPublic(
          targetUserId: pro.uid,
          customerId: customerId,
          customerName: customerName,
          customerPhone: customerPhone,
          customerAddress: customerAddress,
          serviceType: serviceType,
          contactMethod: method.name,
          customerLocation: customerLocation,
        );
        if (fallback['success'] == true) {
          leadSaved = true;
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not show your details to professional. Check backend/Firebase.'),
            ),
          );
          return;
        }
      }

      final uri = contactUriFor(
        method: method,
        phoneNumber: pro.phone,
        message:
            'Assalam-o-Alaikum, I found your profile on Hirepro and want to contact you about ${serviceType.replaceAll('_', ' ')}.',
      );

      final launched = await launchContactUri(uri);
      if (!launched) {
        throw Exception(
            'Could not open ${method == ContactMethod.call ? 'dialer' : 'WhatsApp'}');
      }

      final notifyResult = await _api.sendContactNotification(
        targetUserId: pro.uid,
        title: method == ContactMethod.call
            ? 'Customer called you'
            : 'Customer sent WhatsApp message',
        body:
            '$customerName contacted you for ${serviceType.replaceAll('_', ' ')}. Phone: $customerPhone',
        contactMethod: method.name,
        type: method == ContactMethod.call ? 'direct_call' : 'direct_whatsapp',
        serviceType: serviceType,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        customerLocation: customerLocation,
        leadAlreadySaved: leadSaved,
      );
      if (notifyResult['success'] != true) {
        unawaited(_api.saveContactLeadPublic(
          targetUserId: pro.uid,
          customerId: customerId,
          customerName: customerName,
          customerPhone: customerPhone,
          customerAddress: customerAddress,
          serviceType: serviceType,
          contactMethod: method.name,
          customerLocation: customerLocation,
          leadAlreadySaved: leadSaved,
        ));
      }

      if (mounted) {
        if (method == ContactMethod.whatsapp) {
          unawaited(NotificationService.showLocal(
            title: 'WhatsApp opened',
            body:
                '${pro.name} ko message ready hai. Professional ko aapki details mil gayi hain.',
          ));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              method == ContactMethod.call
                  ? 'Dialer opened. Professional was notified.'
                  : 'WhatsApp opened. Message is ready to send.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _booking = false);
      }
    }
  }

  Future<Map<String, dynamic>> _resolveCustomerContactLocation() async {
    final uid = await StorageService.getUid();
    var lat = _lat;
    var lng = _lng;
    var address = _myArea.trim();

    try {
      final position =
          await LocationService().getCurrentPosition(maxAttempts: 1);
      lat = position.latitude;
      lng = position.longitude;
      address = await LocationService().getAddressFromCoordinates(lat, lng);
      if (mounted) {
        setState(() {
          _lat = lat;
          _lng = lng;
          _myArea = address;
        });
      }
    } catch (_) {
      try {
        if (uid != null && uid.isNotEmpty) {
          final snap = await FirebaseDatabase.instance
              .ref('users/$uid')
              .get()
              .timeout(const Duration(seconds: 5));
          if (snap.value is Map) {
            final data = Map<String, dynamic>.from(snap.value as Map);
            address =
                (data['address'] ?? data['location']?['address'] ?? address)
                    .toString()
                    .trim();
            final location = data['location'];
            if (location is Map) {
              final rawLat = location['lat'];
              final rawLng = location['lng'];
              if (rawLat is num && rawLng is num) {
                lat = rawLat.toDouble();
                lng = rawLng.toDouble();
              }
            }
          }
        }
      } catch (_) {}
    }

    if (address.isEmpty && (lat != 0 || lng != 0)) {
      address =
          'GPS location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }
    if (address.isEmpty) address = 'Location unavailable';

    final location = {'lat': lat, 'lng': lng, 'address': address};
    if (uid != null && uid.isNotEmpty) {
      unawaited(FirebaseDatabase.instance.ref('users/$uid').update({
        'address': address,
        'location': location,
        '_updatedAt': DateTime.now().millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 8), onTimeout: () {}));
    }
    return {'address': address, 'location': location};
  }

  String _bestServiceForContact(ProfessionalModel pro) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      for (final service in pro.allServices) {
        final normalized = service.toLowerCase().replaceAll('_', ' ');
        if (normalized.contains(q) || q.contains(normalized)) {
          return service;
        }
      }
    }
    return pro.allServices.isNotEmpty ? pro.allServices.first : 'general';
  }

  Future<String?> _ensureCustomerPhone(
      {bool requiredForContact = false}) async {
    final uid = await StorageService.getUid();
    if (uid == null || uid.isEmpty || !mounted) return null;
    DataSnapshot snap;
    try {
      snap = await FirebaseDatabase.instance
          .ref('users/$uid/phoneNumber')
          .get()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      if (requiredForContact && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not check your phone number. Try again.')),
        );
      }
      return null;
    }
    final phone = snap.value?.toString().trim() ?? '';
    if (phone.isNotEmpty) return phone;

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '03XXXXXXXXX',
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              final valid = RegExp(r'^(03\d{9}|3\d{9})$')
                  .hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''));
              if (valid) {
                Navigator.pop(ctx, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final value = result?.trim() ?? '';
    if (value.isEmpty) {
      if (requiredForContact && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Phone number is required to contact professionals')),
        );
      }
      return null;
    }
    try {
      await FirebaseDatabase.instance.ref('users/$uid').update({
        'phoneNumber': value,
        '_updatedAt': DateTime.now().millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 8));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save phone number. Try again.')),
        );
      }
      return null;
    }
    return value;
  }

  String _greetingText() {
    return AppHelpers.getGreeting();
  }

  @override
  Widget build(BuildContext context) {
    final name = _userDetails['name'] ?? '';
    final firstName = name.isNotEmpty ? name.split(' ').first : 'Customer';
    final baseServiceKeys =
        AppStrings.serviceCategories.map((c) => c['key'] as String).toSet();
    final customServiceKeys = _all
        .expand((p) => p.customServices)
        .where((service) =>
            service.trim().isNotEmpty && !baseServiceKeys.contains(service))
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // ── App bar / Hero ──────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 220,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppColors.primary,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryDark,
                              AppColors.primary,
                              Color(0xFF6366F1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greetingText()}, $firstName',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Find Trusted Professionals',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Search and book nearby professionals quickly.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                _HeroBadge(label: 'Nearby First'),
                                _HeroBadge(label: 'Direct Contact'),
                                _HeroBadge(label: 'Fast Booking'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Location row
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.white70, size: 16),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _myArea.isNotEmpty
                                        ? _myArea
                                        : (_locationError ??
                                            'Detecting location...'),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _load,
                                  child: const Icon(Icons.refresh,
                                      color: Colors.white70, size: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      const NotificationBell(),
                      // Bookings badge button
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.receipt_long,
                                color: Colors.white),
                            tooltip: 'My Bookings',
                            onPressed: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const MyBookingsScreen()));
                              _load();
                            },
                          ),
                          if (_activeBookingsCount > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFFF6B6B),
                                    shape: BoxShape.circle),
                                child: Center(
                                  child: Text('$_activeBookingsCount',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz, color: Colors.white),
                        tooltip: 'Change Role',
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await StorageService.clearRole();
                          if (!mounted) return;
                          navigator.pushReplacementNamed('/role-selection');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Sign Out',
                        onPressed: _signOut,
                      ),
                    ],
                  ),

                  // ── Search bar ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search by name or service...',
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          hintStyle: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  if (_aiSuggestedService != null &&
                      _aiSuggestedService!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            const Text(
                              'AI Suggestion:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            ActionChip(
                              label: Text(_aiSuggestedService!),
                              avatar: const Icon(Icons.auto_awesome, size: 16),
                              onPressed: () {
                                setState(() {
                                  _filterService = _aiSuggestedService;
                                  _applyFilter();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_suggestions.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.all(10),
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
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _suggestions.map((suggestion) {
                            return ActionChip(
                              avatar: Icon(
                                suggestion.professionalUid == null
                                    ? Icons.build_circle_outlined
                                    : Icons.person_search,
                                size: 17,
                              ),
                              label: Text(
                                suggestion.professionalUid == null
                                    ? '${suggestion.label} (${suggestion.matchCount})'
                                    : suggestion.label,
                              ),
                              onPressed: () => _selectSuggestion(suggestion),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  // ── Category filter chips ───────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.social_distance_rounded,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Distance Filter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _distanceFilterKm == 0
                                        ? 'All'
                                        : '${_distanceFilterKm.round()} km',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor:
                                    AppColors.primary.withOpacity(0.14),
                                thumbColor: AppColors.primary,
                                overlayColor:
                                    AppColors.primary.withOpacity(0.12),
                              ),
                              child: Slider(
                                value: _distanceFilterKm,
                                min: 0,
                                max: _maxRadiusKm,
                                divisions: 20,
                                label: _distanceFilterKm == 0
                                    ? 'All professionals'
                                    : '${_distanceFilterKm.round()} km',
                                onChanged: (value) {
                                  setState(() {
                                    _distanceFilterKm = value.roundToDouble();
                                    _applyFilter();
                                  });
                                },
                              ),
                            ),
                            Text(
                              _distanceFilterKm == 0
                                  ? '0 km par all professionals show honge. Slider increase karein to selected km ke andar professionals filter honge.'
                                  : 'Showing professionals within ${_distanceFilterKm.round()} km.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _CategoryChip(
                            label: 'All Services',
                            selected: _filterService == null,
                            onTap: () => setState(() {
                              _filterService = null;
                              _applyFilter();
                            }),
                          ),
                          ...AppStrings.serviceCategories.map((c) {
                            final key = c['key'] as String;
                            return _CategoryChip(
                              label: '${c['icon']} ${c['name']}',
                              selected: _filterService == key,
                              onTap: () => setState(() {
                                _filterService =
                                    _filterService == key ? null : key;
                                _applyFilter();
                              }),
                            );
                          }),
                          ...customServiceKeys.map((key) {
                            final label = key.replaceAll('_', ' ');
                            return _CategoryChip(
                              label: label,
                              selected: _filterService == key,
                              onTap: () => setState(() {
                                _filterService =
                                    _filterService == key ? null : key;
                                _applyFilter();
                              }),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: const [
                          Expanded(
                            child: _TrustCard(
                              title: 'Nearby Match',
                              subtitle:
                                  'Closest available professionals appear first',
                              icon: Icons.near_me_outlined,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _TrustCard(
                              title: 'Secure Deal',
                              subtitle:
                                  'Phone and location unlock after agreement',
                              icon: Icons.verified_user_outlined,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _TrustCard(
                              title: 'Live Updates',
                              subtitle:
                                  'Track active professionals during work',
                              icon: Icons.location_searching_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_lat != 0 && _filtered.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 200,
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(_lat, _lng),
                                zoom: 12,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('me'),
                                  position: LatLng(_lat, _lng),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueAzure,
                                  ),
                                  infoWindow: const InfoWindow(title: 'You'),
                                ),
                                ..._filtered.take(12).map((p) {
                                  return Marker(
                                    markerId: MarkerId(p.uid),
                                    position: LatLng(p.lat, p.lng),
                                    infoWindow: InfoWindow(
                                      title: p.name,
                                      snippet: p.distanceText,
                                    ),
                                  );
                                }),
                              },
                              myLocationEnabled: true,
                              zoomControlsEnabled: false,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Section header ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Professionals Near You',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_filtered.length}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Professional cards ──────────────────────────────────
                  if (_filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off,
                                size: 64, color: AppColors.textLight),
                            const SizedBox(height: 16),
                            const Text('No professionals found',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final pro = _filtered[i];
                          return AnimatedOpacity(
                            opacity: 1,
                            duration: Duration(milliseconds: 300 + i * 60),
                            child: _ProfessionalCard(
                              professional: pro,
                              onViewProfile: () => Navigator.pushNamed(
                                context,
                                '/professional-profile',
                                arguments: {'uid': pro.uid},
                              ),
                              onCall: _booking
                                  ? null
                                  : () => _contactProfessional(
                                        pro,
                                        method: ContactMethod.call,
                                      ),
                              onWhatsApp: _booking
                                  ? null
                                  : () => _contactProfessional(
                                        pro,
                                        method: ContactMethod.whatsapp,
                                      ),
                            ),
                          );
                        },
                        childCount: _filtered.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }
}

// ── Category Chip ─────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.25), blurRadius: 6)
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Professional Card ─────────────────────────────────────────────────────────
class _SearchSuggestion {
  final String label;
  final String? serviceKey;
  final String? professionalUid;
  final int matchCount;

  const _SearchSuggestion({
    required this.label,
    this.serviceKey,
    this.professionalUid,
    required this.matchCount,
  });
}

class _HeroBadge extends StatelessWidget {
  final String label;

  const _HeroBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TrustCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final ProfessionalModel professional;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onViewProfile;

  const _ProfessionalCard({
    required this.professional,
    this.onCall,
    this.onWhatsApp,
    this.onViewProfile,
  });

  String _serviceLabel(String key) {
    final cat = AppStrings.serviceCategories.firstWhere(
      (c) => c['key'] == key,
      orElse: () => {'name': key.replaceAll('_', ' '), 'icon': ''},
    );
    final icon = cat['icon']?.toString() ?? '';
    final name = cat['name']?.toString() ?? key;
    return icon.isEmpty ? name : '$icon $name';
  }

  @override
  Widget build(BuildContext context) {
    final services =
        professional.serviceTypes.take(3).map(_serviceLabel).join(' | ');
    final isAvailable = professional.isAvailable;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                GestureDetector(
                  onTap: onViewProfile,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      image: professional.photoURL.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(professional.photoURL),
                              fit: BoxFit.cover,
                            )
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: professional.photoURL.isEmpty
                          ? Text(
                              professional.name.isNotEmpty
                                  ? professional.name[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              professional.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? AppColors.success.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? AppColors.success
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAvailable ? 'Online' : 'Offline',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isAvailable
                                          ? AppColors.success
                                          : Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        services.isNotEmpty ? services : 'Professional',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Rating
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.star, size: 17),
                    const SizedBox(width: 3),
                    Text(
                      professional.ratingText,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Distance
                Row(
                  children: [
                    const Icon(Icons.near_me,
                        color: AppColors.primary, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      professional.distanceText,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                if (professional.completedJobs > 0) ...[
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        color: AppColors.accent,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${professional.completedJobs} jobs',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
              ],
            ),
            if (professional.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place, size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      professional.address,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 355;
                final buttons = [
                  _CardActionButton(
                    label: 'Profile',
                    icon: Icons.person,
                    onPressed: onViewProfile,
                    foreground: AppColors.accent,
                    outlined: true,
                  ),
                  _CardActionButton(
                    label: 'Call',
                    icon: Icons.call,
                    onPressed: isAvailable ? onCall : null,
                    foreground: isAvailable ? AppColors.primary : Colors.grey,
                    outlined: true,
                  ),
                  _CardActionButton(
                    label: 'WhatsApp',
                    icon: Icons.chat,
                    onPressed: isAvailable ? onWhatsApp : null,
                    foreground: Colors.white,
                    background:
                        isAvailable ? const Color(0xFF25D366) : Colors.grey,
                  ),
                ];
                if (compact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: buttons[0]),
                          const SizedBox(width: 8),
                          Expanded(child: buttons[1]),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: buttons[2]),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: buttons[0]),
                    const SizedBox(width: 8),
                    Expanded(child: buttons[1]),
                    const SizedBox(width: 8),
                    Expanded(child: buttons[2]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color foreground;
  final Color? background;
  final bool outlined;

  const _CardActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.foreground,
    this.background,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );

    if (outlined) {
      return SizedBox(
        height: 42,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: foreground.withOpacity(0.65)),
            foregroundColor: foreground,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: onPressed == null ? 0 : 2,
        ),
        child: child,
      ),
    );
  }
}
