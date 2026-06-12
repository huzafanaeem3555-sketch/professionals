import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/snackbar_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/professional_model.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../utils/contact_actions.dart';
import '../utils/location_prompt.dart';
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
  final _areaCtrl = TextEditingController();

  double _lat = 0;
  double _lng = 0;
  List<ProfessionalModel> _all = [];
  List<ProfessionalModel> _filtered = [];
  List<_SearchSuggestion> _suggestions = [];
  Map<String, int> _servicePopularity = {};
  Set<String> _favoriteIds = {};
  int _activeBookingsCount = 0;
  String? _filterService;
  String _areaFilter = '';
  String _myArea = '';
  bool _loading = true;
  bool _booking = false;
  String? _locationError;
  double _distanceFilterKm = 0;
  Map<String, String> _userDetails = {};
  String _customerGender = 'male';
  String _customerVerificationStatus = 'verified';
  String? _aiSuggestedService;
  Timer? _aiSuggestDebounce;
  String? _voiceStatus;
  bool _voiceAvailable = false;
  bool _voiceListening = false;

  late AnimationController _animCtrl;
  static const MethodChannel _voiceChannel =
      MethodChannel('hirepro/voice_search');

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
    _areaCtrl.dispose();
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
    final popularServicesFuture = _api.getPopularServices(limit: 80);
    final favoritesFuture = _api.getFavorites();

    try {
      final locationReady = await ensureLocationEnabled(
        context,
        message:
            'Please turn on location so HirePro can sort nearby professionals and enable live map tracking.',
      );
      if (!locationReady) {
        throw Exception('Location is turned off.');
      }
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
    await _loadReferralState(customerId);
    await _loadCustomerPrivacy();
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
    final visibleList = list.where(_canShowProfessional).toList();
    _sortProfessionals(visibleList);

    final bookings = await bookingsFuture;
    final servicePopularity =
        await _resolveServicePopularity(popularServicesFuture);
    final favoriteIds = await _resolveFavoriteIds(favoritesFuture);
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
        _all = visibleList;
        _servicePopularity = servicePopularity;
        _favoriteIds = favoriteIds;
        _activeBookingsCount = activeCount;
        _applyFilter();
        _buildSuggestions(_searchCtrl.text);
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  Future<void> _loadCustomerPrivacy() async {
    final uid = await StorageService.getUid();
    _customerGender = await StorageService.getGender() ?? 'male';
    _customerVerificationStatus =
        await StorageService.getVerificationStatus() ?? 'verified';
    if (uid == null || uid.isEmpty) return;
    try {
      final snap = await FirebaseDatabase.instance.ref('users/$uid').get();
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        _customerGender =
            data['gender']?.toString().toLowerCase() ?? _customerGender;
        _customerVerificationStatus = data['verificationStatus']?.toString() ??
            _customerVerificationStatus;
        await StorageService.setGender(_customerGender);
        await StorageService.setVerificationStatus(_customerVerificationStatus);
      }
    } catch (_) {}
    if (_customerGender == 'female' &&
        _customerVerificationStatus.toLowerCase() != 'verified' &&
        mounted) {
      Navigator.pushReplacementNamed(
        context,
        '/gender-verification',
        arguments: 'customer',
      );
    }
  }

  Future<void> _loadReferralState(String customerId) async {
    if (customerId.isEmpty) return;
    try {
      final snap =
          await FirebaseDatabase.instance.ref('users/$customerId').get();
      if (!snap.exists || snap.value is! Map) return;
      final data = Map<String, dynamic>.from(snap.value as Map);
      void putString(String key) {
        final value = data[key]?.toString() ?? '';
        if (value.isNotEmpty) _userDetails[key] = value;
      }

      putString('activeReferralCode');
      putString('referredProfessionalId');
      putString('referralDiscountPercent');
      putString('referralOwnerId');
      putString('referralOwnerName');
    } catch (_) {
      // Referral data is optional; normal browsing should still work.
    }
  }

  bool _canShowProfessional(ProfessionalModel pro) {
    if (!pro.isActive) return false;
    final proGender = pro.gender.toLowerCase();
    if (_customerGender == 'female') {
      return proGender == 'female' &&
          _customerVerificationStatus == 'verified' &&
          pro.verificationStatus == 'verified';
    }
    if (proGender == 'female') return false;
    return true;
  }

  void _applyFilter() {
    var list = List<ProfessionalModel>.from(_all);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (_lat != 0 && _lng != 0 && _distanceFilterKm > 0) {
      list =
          list.where((p) => (p.distance ?? 999) <= _distanceFilterKm).toList();
    }
    if (_areaFilter.trim().isNotEmpty) {
      final area = _normalizeSearchText(_areaFilter);
      list = list.where((p) {
        final address = _normalizeSearchText(p.address);
        final serviceText = _normalizeSearchText(p.serviceText);
        return address.contains(area) || serviceText.contains(area);
      }).toList();
    }
    if (_filterService != null && _filterService!.isNotEmpty) {
      list = list.where((p) {
        return p.allServices.any((service) =>
            _sameService(service, _filterService!) ||
            _matchesQuery(ServiceLabels.getName(service), _filterService!));
      }).toList();
    }
    if (q.isNotEmpty) {
      final searched = list.where((p) {
        return _professionalMatchesQuery(p, q);
      }).toList();
      list = searched;

      int score(ProfessionalModel p) {
        var points = 0;
        final normalizedQuery = _normalizeSearchText(q);
        final name = _normalizeSearchText(p.name);
        final services = p.allServices
            .map((service) => '$service ${_displayServiceName(service)}')
            .join(' ');
        final normalizedServices = _normalizeSearchText(services);
        if (normalizedServices.startsWith(normalizedQuery)) points += 140;
        if (normalizedServices.contains(normalizedQuery)) points += 110;
        if (name.startsWith(normalizedQuery)) points += 80;
        if (name.contains(normalizedQuery)) points += 55;
        if (normalizedQuery.length >= 3 &&
            _normalizeSearchText(p.address).contains(normalizedQuery)) {
          points += 12;
        }
        points += _professionalPopularityScore(p);
        if (p.isAvailable) points += 10;
        final distancePenalty = (p.distance ?? 999).clamp(0, 200).toInt();
        return points - distancePenalty;
      }

      list.sort((a, b) {
        final diff = score(b).compareTo(score(a));
        if (diff != 0) return diff;
        return (a.distance ?? 999).compareTo(b.distance ?? 999);
      });
    } else {
      _sortProfessionals(list);
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
      unawaited(_trackServiceSearch(query: q));
      await _applyAiServiceSearch(q);
    });
  }

  Future<void> _startVoiceSearch() async {
    if (_voiceListening) return;
    setState(() {
      _voiceListening = true;
      _voiceAvailable = true;
      _voiceStatus = 'Listening... speak the service or issue in English.';
    });
    try {
      final words = await _voiceChannel
          .invokeMethod<String>('listen')
          .timeout(const Duration(seconds: 16), onTimeout: () async {
        try {
          await _voiceChannel.invokeMethod<void>('stop');
        } catch (_) {}
        return '';
      });
      if (!mounted) return;
      final spokenText = words?.trim() ?? '';
      if (spokenText.isEmpty) {
        setState(() {
          _voiceListening = false;
          _voiceStatus = 'No voice detected. Try again or type service.';
        });
        return;
      }
      setState(() {
        _searchCtrl.text = spokenText;
        _searchCtrl.selection =
            TextSelection.collapsed(offset: spokenText.length);
        _filterService = null;
        _voiceListening = false;
        _voiceStatus = 'Searching for "$spokenText"...';
        _buildSuggestions(spokenText);
        _applyFilter();
      });
      await _applyVoiceSearchText(spokenText);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final needsPermission = e.code == 'permission_denied';
      setState(() {
        _voiceListening = false;
        _voiceAvailable = !needsPermission;
        _voiceStatus = needsPermission
            ? 'Microphone permission needed for voice search.'
            : 'Voice search unavailable. Type your service.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voiceListening = false;
        _voiceStatus = 'Voice search could not start. Try typing instead.';
      });
    }
  }

  Future<void> _stopVoiceSearch() async {
    try {
      await _voiceChannel.invokeMethod<void>('stop');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _voiceListening = false;
      _voiceStatus = null;
    });
  }

  Future<void> _applyVoiceSearchText(String words) async {
    _aiSuggestDebounce?.cancel();
    await _applyAiServiceSearch(words, autoApply: true);
  }

  Future<void> _applyAiServiceSearch(
    String query, {
    bool autoApply = false,
  }) async {
    final fallback = _inferServiceFromSpeech(query);
    if (fallback != null && mounted) {
      setState(() {
        _aiSuggestedService = fallback;
        if (autoApply) {
          _filterService = fallback;
          _voiceStatus =
              'Showing ${_displayServiceName(fallback)} professionals.';
        }
        _applyFilter();
      });
    }

    final backendApplied =
        await _applyBackendAiSearchResults(query, autoApply: autoApply);
    if (backendApplied) return;

    if (query.trim().length < 4) return;
    final res = await _api.recommendService(query);
    if (!mounted) return;
    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final suggested = data['serviceType']?.toString();
      if (suggested != null && suggested.isNotEmpty) {
        setState(() {
          _aiSuggestedService = suggested;
          if (autoApply) {
            _filterService = suggested;
            _voiceStatus =
                'Showing ${_displayServiceName(suggested)} professionals.';
          }
          _applyFilter();
        });
      }
    } else if (autoApply && fallback == null) {
      setState(() {
        _voiceStatus = 'No exact service found. Showing closest results.';
        _applyFilter();
      });
    }
  }

  Future<bool> _applyBackendAiSearchResults(
    String query, {
    bool autoApply = false,
  }) async {
    if (query.trim().length < 2) return false;
    final res = await _api.searchProfessionals(query);
    if (!mounted || res['success'] != true || res['data'] is! Map) {
      return false;
    }

    final data = Map<String, dynamic>.from(res['data'] as Map);
    final results = data['results'];
    if (results is! List) return false;

    final models = <ProfessionalModel>[];
    for (final item in results) {
      if (item is! Map) continue;
      final raw = Map<String, dynamic>.from(item);
      final uid = raw['uid']?.toString() ?? '';
      ProfessionalModel? existing;
      for (final pro in _all) {
        if (pro.uid == uid) {
          existing = pro;
          break;
        }
      }
      final model = existing ?? ProfessionalModel.fromJson(raw);
      if (!_canShowProfessional(model)) continue;
      if (_lat != 0 &&
          _lng != 0 &&
          _distanceFilterKm > 0 &&
          (model.distance ?? 999) > _distanceFilterKm) {
        continue;
      }
      if (_areaFilter.trim().isNotEmpty) {
        final area = _normalizeSearchText(_areaFilter);
        if (!_normalizeSearchText(model.address).contains(area) &&
            !_normalizeSearchText(model.serviceText).contains(area)) {
          continue;
        }
      }
      models.add(model);
    }

    final matchedServices = data['matchedServices'];
    final suggested = matchedServices is List && matchedServices.isNotEmpty
        ? matchedServices.first.toString()
        : null;
    setState(() {
      if (suggested != null && suggested.isNotEmpty) {
        _aiSuggestedService = suggested;
      }
      _filtered = models;
      if (autoApply && suggested != null && suggested.isNotEmpty) {
        _voiceStatus =
            'Showing ${_displayServiceName(suggested)} professionals.';
      } else if (autoApply && models.isEmpty) {
        _voiceStatus = 'No available professionals found for this search.';
      }
    });
    return true;
  }

  String? _inferServiceFromSpeech(String value) {
    final raw = value.toLowerCase();
    final normalized = _normalizeSearchText(value);
    final text = '$raw $normalized';
    final synonym = _serviceFromSynonym(text);
    if (synonym != null) return synonym;
    const keywords = <String, List<String>>{
      'electrician': [
        'electric',
        'electrician',
        'bijli',
        'light',
        'wiring',
        'fan',
        'switch',
      ],
      'plumber': [
        'plumber',
        'pani',
        'pipe',
        'leak',
        'nal',
        'tap',
        'bathroom',
      ],
      'carpenter': [
        'carpenter',
        'wood',
        'furniture',
        'door',
        'darwaza',
        'lakri',
      ],
      'ac_mechanic': [
        'ac',
        'a c',
        'air condition',
        'cooling',
        'fridge',
        'refrigerator',
        'thanda',
      ],
      'painter': ['paint', 'painter', 'rang', 'wall'],
      'cleaner': ['clean', 'cleaner', 'safai'],
      'tutor': ['teacher', 'tutor', 'study', 'parhai', 'math', 'english'],
      'driver': ['driver', 'car', 'gaari', 'gari'],
      'chef': ['cook', 'chef', 'cooking', 'khana'],
      'beautician': ['beauty', 'salon', 'makeup', 'mehndi', 'bridal'],
      'it_technician': [
        'computer',
        'laptop',
        'mobile',
        'wifi',
        'internet',
        'network',
        'software',
        'web',
      ],
      'security_guard': ['security', 'guard', 'chowkidar', 'watchman'],
    };
    for (final entry in keywords.entries) {
      if (entry.value.any((keyword) => text.contains(keyword))) {
        return entry.key;
      }
    }
    return null;
  }

  String? _serviceFromSynonym(String text) {
    final groups = <String, List<String>>{
      'plumber': [
        'pani leak',
        'nal kharab',
        'pipe masla',
        'pipe issue',
        'water leakage',
        'drain block',
        'sewerage',
        'gutter',
        'flush',
        'commode',
        'wash basin',
        'sink',
        'tank overflow',
        'motor pump',
        'valve',
        'shower',
        'tooti',
        'nali',
        'pani band'
      ],
      'electrician': [
        'bijli ka masla',
        'light not working',
        'fan slow',
        'switch board',
        'socket',
        'breaker',
        'ups wiring',
        'inverter',
        'short circuit',
        'fuse',
        'spark',
        'meter',
        'voltage',
        'plug',
        'tube light',
        'led light',
        'phase',
        'wire jal gai'
      ],
      'ac_mechanic': [
        'ac not cooling',
        'ac cooling',
        'ac gas',
        'split ac',
        'window ac',
        'compressor',
        'fridge cooling',
        'deep freezer',
        'freezer',
        'water dispenser',
        'outdoor unit',
        'indoor unit'
      ],
      'carpenter': [
        'darwaza',
        'almari',
        'wardrobe',
        'cabinet',
        'kitchen cabinet',
        'bed repair',
        'furniture repair',
        'chair repair',
        'table repair',
        'drawer',
        'hinge',
        'wood work',
        'polish'
      ],
      'painter': [
        'rang',
        'wall paint',
        'safedi',
        'distemper',
        'emulsion',
        'ceiling paint',
        'wallpaper',
        'texture',
        'door paint'
      ],
      'cleaner': [
        'safai',
        'deep cleaning',
        'bathroom cleaning',
        'kitchen cleaning',
        'sofa cleaning',
        'carpet cleaning',
        'floor wash',
        'maid',
        'housekeeping',
        'office cleaning'
      ],
      'tutor': [
        'parhai',
        'math teacher',
        'english teacher',
        'home tuition',
        'quran teacher',
        'physics',
        'chemistry',
        'biology',
        'computer class',
        'academy'
      ],
      'driver': [
        'driver needed',
        'car driver',
        'pick and drop',
        'school van',
        'rent a car',
        'chauffeur',
        'airport drop',
        'daily driver'
      ],
      'chef': [
        'khana pakana',
        'cook needed',
        'bawarchi',
        'roti',
        'biryani',
        'catering',
        'home cook',
        'party food'
      ],
      'beautician': [
        'mehndi',
        'bridal',
        'salon',
        'facial',
        'hair cut',
        'hair color',
        'threading',
        'wax',
        'party makeup',
        'nails'
      ],
      'it_technician': [
        'laptop repair',
        'mobile repair',
        'wifi issue',
        'internet problem',
        'cctv',
        'printer',
        'router',
        'windows install',
        'data recovery',
        'screen repair',
        'charging jack',
        'keyboard issue',
        'pc repair'
      ],
      'security_guard': [
        'chowkidar',
        'watchman',
        'night guard',
        'gate keeper',
        'body guard',
        'security guard'
      ],
      'gardener': ['garden', 'gardener', 'lawn', 'plants', 'grass', 'mali'],
      'mechanic': [
        'car repair',
        'bike repair',
        'engine',
        'oil change',
        'brake',
        'clutch',
        'puncture'
      ],
      'welder': ['welding', 'gate welding', 'grill', 'iron work', 'steel'],
      'mason': ['mistri', 'tiles', 'brick work', 'cement', 'wall repair'],
    };
    for (final entry in groups.entries) {
      if (entry.value.any((word) => text.contains(word))) return entry.key;
    }
    return null;
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
          final popularity = _serviceScore(service);
          suggestions.putIfAbsent(
            service.toLowerCase(),
            () => _SearchSuggestion(
              label: label,
              serviceKey: service,
              matchCount: _all
                  .where(
                      (p) => p.allServices.any((s) => _sameService(s, service)))
                  .length,
              popularity: popularity,
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
            popularity: _professionalPopularityScore(pro),
          ),
        );
      }
    }

    final list = suggestions.values.toList()
      ..sort((a, b) {
        final popularityDiff = b.popularity.compareTo(a.popularity);
        if (popularityDiff != 0) return popularityDiff;
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
      if (suggestion.serviceKey != null) {
        unawaited(_trackServiceSearch(serviceType: suggestion.serviceKey));
      }
      if (suggestion.professionalUid != null) {
        _filtered =
            _all.where((p) => p.uid == suggestion.professionalUid).toList();
      } else {
        _applyFilter();
      }
    });
  }

  bool _professionalMatchesQuery(ProfessionalModel p, String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (_matchesQuery(p.name, query)) {
      return true;
    }
    for (final service in p.allServices) {
      if (_matchesQuery(service, query) ||
          _matchesQuery(service.replaceAll('_', ' '), query) ||
          _matchesQuery(_displayServiceName(service), query)) {
        return true;
      }
    }
    if (normalizedQuery.length >= 3 && _matchesQuery(p.address, query)) {
      return true;
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

  String _serviceKey(String value) {
    return _normalizeSearchText(value).replaceAll(' ', '_');
  }

  int _serviceScore(String service) {
    final keys = {
      _serviceKey(service),
      _serviceKey(service.replaceAll('_', ' ')),
      _serviceKey(_displayServiceName(service)),
    };
    var best = 0;
    for (final key in keys) {
      final value = _servicePopularity[key] ?? 0;
      if (value > best) best = value;
    }
    return best;
  }

  int _professionalPopularityScore(ProfessionalModel p) {
    final serviceScore = p.allServices.fold<int>(0, (best, service) {
      final score = _serviceScore(service);
      return score > best ? score : best;
    });
    return (p.rating * 1000).round() +
        (p.isFeatured ? 10000 : 0) +
        (p.trustScore * 18) +
        (p.totalRatings * 12) +
        (p.completedJobs * 8) +
        (serviceScore * 4);
  }

  void _sortProfessionals(List<ProfessionalModel> list) {
    list.sort((a, b) {
      final scoreDiff = _professionalPopularityScore(b)
          .compareTo(_professionalPopularityScore(a));
      if (scoreDiff != 0) return scoreDiff;
      return (a.distance ?? 999).compareTo(b.distance ?? 999);
    });
  }

  Future<Map<String, int>> _resolveServicePopularity(
    Future<Map<String, dynamic>> future,
  ) async {
    try {
      final res = await future.timeout(const Duration(seconds: 8));
      final data = res['data'];
      if (res['success'] != true || data is! List) return {};
      final map = <String, int>{};
      for (final raw in data) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final rawKey = (item['serviceKey'] ?? item['label'] ?? '').toString();
        final label = (item['label'] ?? rawKey).toString();
        final score = (item['score'] is num)
            ? (item['score'] as num).round()
            : int.tryParse(item['score']?.toString() ?? '') ?? 0;
        final usage = (item['totalUsage'] is num)
            ? (item['totalUsage'] as num).round()
            : int.tryParse(item['totalUsage']?.toString() ?? '') ?? 0;
        final value = score > 0 ? score : usage;
        if (value <= 0) continue;
        map[_serviceKey(rawKey)] = value;
        map[_serviceKey(label)] = value;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> _resolveFavoriteIds(
    Future<Map<String, dynamic>> future,
  ) async {
    try {
      final res = await future.timeout(const Duration(seconds: 8));
      final data = res['data'];
      if (res['success'] != true || data is! List) return {};
      return data
          .whereType<Map>()
          .map((item) => (item['professionalId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _trackServiceSearch({String? query, String? serviceType}) async {
    await _api.trackServiceSearch(query: query, serviceType: serviceType);
  }

  Future<void> _toggleFavorite(ProfessionalModel pro) async {
    final currentlySaved = _favoriteIds.contains(pro.uid);
    setState(() {
      if (currentlySaved) {
        _favoriteIds.remove(pro.uid);
      } else {
        _favoriteIds.add(pro.uid);
      }
    });
    final res = await _api.toggleFavorite(pro.uid, favorite: !currentlySaved);
    if (res['success'] != true && mounted) {
      setState(() {
        if (currentlySaved) {
          _favoriteIds.add(pro.uid);
        } else {
          _favoriteIds.remove(pro.uid);
        }
      });
      showTimedSnackBar(
        context,
        SnackBar(
            content: Text(res['message']?.toString() ?? 'Favorite failed')),
      );
    }
  }

  Future<void> _submitComplaint(ProfessionalModel pro) async {
    final controller = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complaint: ${pro.name}'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Issue detail',
            hintText: 'Write what happened...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (sent != true || reason.isEmpty) return;
    final res = await _api.createComplaint({
      'professionalId': pro.uid,
      'reason': reason,
    });
    if (!mounted) return;
    showTimedSnackBar(
      context,
      SnackBar(
        content: Text(res['success'] == true
            ? 'Complaint sent to admin.'
            : res['message']?.toString() ?? 'Complaint failed'),
        backgroundColor:
            res['success'] == true ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _createReferral(ProfessionalModel pro) async {
    final res = await _api.createReferral({
      'professionalId': pro.uid,
      'discountPercent': 10,
    });
    if (!mounted) return;
    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final code = data['code']?.toString() ?? '';
      await Clipboard.setData(ClipboardData(text: code));
      showTimedSnackBar(
        context,
        SnackBar(
          content: Text('Referral code copied: $code'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      showTimedSnackBar(
        context,
        SnackBar(
            content: Text(res['message']?.toString() ?? 'Referral failed')),
      );
    }
  }

  Future<void> _openCustomerJobs() async {
    await Navigator.pushNamed(context, '/customer-jobs');
    if (mounted) _load();
  }

  Future<void> _showMyProfile() async {
    final details = await StorageService.getUserDetails();
    final name = details['name']?.trim() ?? '';
    final email = details['email']?.trim() ?? '';
    final phone = details['phone']?.trim() ?? '';
    final photo = details['photo']?.trim() ?? '';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.surfaceLight,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              name.isNotEmpty ? name : 'Customer',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                phone,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '${_customerGender == 'female' ? 'Female' : 'Male'} customer | $_customerVerificationStatus',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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

  Future<void> _openAiEstimator() async {
    await Navigator.pushNamed(context, '/ai-estimator');
    if (mounted) _load();
  }

  void _showSavedProfessionals() {
    setState(() {
      _filtered = _all.where((p) => _favoriteIds.contains(p.uid)).toList();
    });
    showTimedSnackBar(
      context,
      SnackBar(
        content: Text(
          _favoriteIds.isEmpty
              ? 'No saved professionals yet.'
              : 'Showing ${_favoriteIds.length} saved professionals.',
        ),
      ),
    );
  }

  Future<void> _applyReferralDialog() async {
    final controller = TextEditingController();
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply Referral Code'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Referral code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    final code = controller.text.trim();
    controller.dispose();
    if (apply != true || code.isEmpty) return;
    final res = await _api.applyReferral(code);
    if (!mounted) return;
    if (res['success'] == true && res['data'] is Map) {
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final proId = data['professionalId']?.toString() ?? '';
      final discount = data['discountPercent']?.toString() ?? '10';
      final referralCode = data['code']?.toString() ?? code.toUpperCase();
      final ownerId = data['ownerId']?.toString() ?? '';
      final ownerName = data['ownerName']?.toString() ?? 'Customer';
      setState(() {
        _userDetails['activeReferralCode'] = referralCode;
        _userDetails['referredProfessionalId'] = proId;
        _userDetails['referralDiscountPercent'] = discount;
        _userDetails['referralOwnerId'] = ownerId;
        _userDetails['referralOwnerName'] = ownerName;
        if (proId.isNotEmpty) {
          _filtered = _all.where((p) => p.uid == proId).toList();
        }
      });
      showTimedSnackBar(
        context,
        SnackBar(
          content: Text('Referral applied. Discount: $discount%'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      showTimedSnackBar(
        context,
        SnackBar(content: Text(res['message']?.toString() ?? 'Invalid code')),
      );
    }
  }

  Future<void> _postJobDialog() async {
    final titleCtrl = TextEditingController();
    final serviceCtrl = TextEditingController(text: _filterService ?? '');
    final descCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '20');
    var urgent = false;
    DateTime? scheduledAt;
    final post = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Post a Job'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile.adaptive(
                  value: urgent,
                  onChanged: (value) => setDialogState(() => urgent = value),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.error,
                  title: const Text('Need Now'),
                  subtitle:
                      const Text('Send priority alert to nearby online pros.'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Job title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: serviceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Service',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Work details',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: budgetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Budget PKR',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: radiusCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Radius KM',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Job date/time optional',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        scheduledAt == null
                            ? 'No auto-expiry. You can delete it manually.'
                            : DateFormat('dd MMM yyyy, h:mm a')
                                .format(scheduledAt!),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final date = await showDatePicker(
                                context: ctx,
                                initialDate: scheduledAt ?? now,
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 365)),
                              );
                              if (date == null || !ctx.mounted) return;
                              final time = await showTimePicker(
                                context: ctx,
                                initialTime: TimeOfDay.fromDateTime(
                                  scheduledAt ??
                                      now.add(const Duration(hours: 2)),
                                ),
                              );
                              if (time == null) return;
                              setDialogState(() {
                                scheduledAt = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            },
                            icon: const Icon(Icons.event_rounded),
                            label: const Text('Set time'),
                          ),
                          if (scheduledAt != null)
                            TextButton(
                              onPressed: () =>
                                  setDialogState(() => scheduledAt = null),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
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
              child: Text(urgent ? 'Post Urgent' : 'Post'),
            ),
          ],
        ),
      ),
    );
    final title = titleCtrl.text.trim();
    final service = serviceCtrl.text.trim();
    final desc = descCtrl.text.trim();
    final budget = double.tryParse(budgetCtrl.text.trim()) ?? 0;
    final radius = double.tryParse(radiusCtrl.text.trim()) ?? 20;
    titleCtrl.dispose();
    serviceCtrl.dispose();
    descCtrl.dispose();
    budgetCtrl.dispose();
    radiusCtrl.dispose();
    if (post != true || service.isEmpty || desc.isEmpty) return;
    final contactLocation = await _resolveCustomerContactLocation();
    await NotificationService.syncTokenForCurrentUser();
    final res = await _api.createJobPost({
      'title': title.isEmpty ? service : title,
      'serviceType': service,
      'description': desc,
      'budget': budget,
      'radiusKm': radius,
      'isUrgent': urgent,
      'priority': urgent ? 'urgent' : 'normal',
      'location': contactLocation['location'],
      'address': contactLocation['address'],
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
    });
    if (!mounted) return;
    if (res['success'] == true) {
      await NotificationService.showLocal(
        title: 'Job posted',
        body: urgent
            ? 'Urgent job is live. Nearby professionals will receive priority alert.'
            : 'Your job is live. Professionals will receive a phone alert.',
      );
    }
    showTimedSnackBar(
      context,
      SnackBar(
        content: Text(res['success'] == true
            ? 'Job posted. Nearby professionals can send offers.'
            : res['message']?.toString() ?? 'Job post failed'),
        backgroundColor:
            res['success'] == true ? AppColors.success : AppColors.error,
        action: res['success'] == true
            ? SnackBarAction(
                label: 'My Jobs',
                textColor: Colors.white,
                onPressed: _openCustomerJobs,
              )
            : null,
      ),
    );
  }

  void _autoMatchBest() {
    if (_filtered.isEmpty) {
      showTimedSnackBar(
        context,
        const SnackBar(content: Text('Select a service or search first.')),
      );
      return;
    }
    _sortProfessionals(_filtered);
    final best = _filtered.first;
    showTimedSnackBar(
      context,
      SnackBar(
        content:
            Text('Best match: ${best.name} (${best.trustScore}% reliable)'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pushNamed(
      context,
      '/professional-profile',
      arguments: {'uid': best.uid},
    );
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
      showTimedSnackBar(
        context,
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
      final referralCode = _userDetails['activeReferralCode'] ?? '';
      final referredProfessionalId =
          _userDetails['referredProfessionalId'] ?? '';
      final hasReferralDiscount =
          referralCode.isNotEmpty && referredProfessionalId == pro.uid;
      final referralDiscountPercent =
          _userDetails['referralDiscountPercent'] ?? '';
      final referralOwnerId = _userDetails['referralOwnerId'] ?? '';
      final referralOwnerName = _userDetails['referralOwnerName'] ?? '';
      var leadSaved = await _firebase.saveContactLead(
        professionalId: pro.uid,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        serviceType: serviceType,
        contactMethod: method.name,
        customerLocation: customerLocation,
        referralCode: hasReferralDiscount ? referralCode : null,
        referralDiscountPercent:
            hasReferralDiscount ? referralDiscountPercent : null,
        referralOwnerId: hasReferralDiscount ? referralOwnerId : null,
        referralOwnerName: hasReferralDiscount ? referralOwnerName : null,
        hasReferralDiscount: hasReferralDiscount,
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
          referralCode: hasReferralDiscount ? referralCode : null,
          referralDiscountPercent:
              hasReferralDiscount ? referralDiscountPercent : null,
          referralOwnerId: hasReferralDiscount ? referralOwnerId : null,
          referralOwnerName: hasReferralDiscount ? referralOwnerName : null,
          hasReferralDiscount: hasReferralDiscount,
        );
        if (fallback['success'] == true) {
          leadSaved = true;
        } else if (mounted) {
          showTimedSnackBar(
            context,
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
            'Hello, I found your profile on HirePro and want to contact you about ${serviceType.replaceAll('_', ' ')}.',
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
        referralCode: hasReferralDiscount ? referralCode : null,
        referralDiscountPercent:
            hasReferralDiscount ? referralDiscountPercent : null,
        referralOwnerId: hasReferralDiscount ? referralOwnerId : null,
        referralOwnerName: hasReferralDiscount ? referralOwnerName : null,
        hasReferralDiscount: hasReferralDiscount,
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
          referralCode: hasReferralDiscount ? referralCode : null,
          referralDiscountPercent:
              hasReferralDiscount ? referralDiscountPercent : null,
          referralOwnerId: hasReferralDiscount ? referralOwnerId : null,
          referralOwnerName: hasReferralDiscount ? referralOwnerName : null,
          hasReferralDiscount: hasReferralDiscount,
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
        showTimedSnackBar(
          context,
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
      final locationReady = await ensureLocationEnabled(
        context,
        message:
            'Please turn on location so the professional can see your area and reach you accurately.',
      );
      if (!locationReady) {
        throw Exception('Location is turned off.');
      }
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
        showTimedSnackBar(
          context,
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
        showTimedSnackBar(
          context,
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
        showTimedSnackBar(
          context,
          const SnackBar(
              content: Text('Could not save phone number. Try again.')),
        );
      }
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _loading
          ? null
          : _CustomerActionBar(
              favoriteCount: _favoriteIds.length,
              onAutoMatch: _autoMatchBest,
              onPostJob: _postJobDialog,
              onEstimator: _openAiEstimator,
              onJobs: _openCustomerJobs,
              onSaved: _showSavedProfessionals,
              onReferral: _applyReferralDialog,
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // â”€â”€ App bar / Hero â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SliverAppBar(
                    expandedHeight: 230,
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
                              AppColors.primaryLight,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 72, 20, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Find nearby professionals',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'How to use it:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const _HowToUseStrip(),
                            const SizedBox(height: 10),
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
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: IconButton(
                          tooltip: 'My Profile',
                          onPressed: _showMyProfile,
                          icon: CircleAvatar(
                            radius: 15,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.22),
                            backgroundImage:
                                (_userDetails['photo'] ?? '').isNotEmpty
                                    ? NetworkImage(_userDetails['photo']!)
                                    : null,
                            child: (_userDetails['photo'] ?? '').isEmpty
                                ? Text(
                                    (_userDetails['name'] ?? '').isNotEmpty
                                        ? _userDetails['name']![0].toUpperCase()
                                        : 'C',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const NotificationBell(),
                      IconButton(
                        icon: const Icon(Icons.work_history_rounded,
                            color: Colors.white),
                        tooltip: 'My Jobs',
                        onPressed: _openCustomerJobs,
                      ),
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

                  // â”€â”€ Search bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Search your required Services here',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search or speak a service...',
                              prefixIcon: const Icon(Icons.search,
                                  color: AppColors.primary),
                              suffixIcon: IconButton(
                                tooltip: _voiceListening
                                    ? 'Stop voice search'
                                    : 'Voice search',
                                onPressed: _loading
                                    ? null
                                    : (_voiceListening
                                        ? _stopVoiceSearch
                                        : _startVoiceSearch),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    _voiceListening
                                        ? Icons.stop_circle
                                        : Icons.mic,
                                    key: ValueKey(_voiceListening),
                                    color: _voiceListening
                                        ? AppColors.error
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
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
                          if (_voiceStatus != null || _voiceListening)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: (_voiceAvailable || _voiceListening)
                                      ? AppColors.primary.withOpacity(0.08)
                                      : AppColors.error.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _voiceListening
                                          ? Icons.graphic_eq
                                          : Icons.auto_awesome,
                                      size: 18,
                                      color:
                                          (_voiceAvailable || _voiceListening)
                                              ? AppColors.primary
                                              : AppColors.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _voiceStatus ??
                                            'Listening for your service...',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: (_voiceAvailable ||
                                                  _voiceListening)
                                              ? AppColors.textPrimary
                                              : AppColors.error,
                                          fontSize: 12,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
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

                  // â”€â”€ Category filter chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                                  ? '0 km shows all professionals. Increase the slider to filter professionals within the selected distance.'
                                  : 'Showing professionals within ${_distanceFilterKm.round()} km.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _areaCtrl,
                              onChanged: (value) {
                                setState(() {
                                  _areaFilter = value;
                                  _applyFilter();
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Area / city filter',
                                hintText: 'Example: Lahore, DHA, Saddar',
                                prefixIcon: const Icon(
                                  Icons.location_city_rounded,
                                  color: AppColors.primary,
                                ),
                                suffixIcon: _areaFilter.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear area filter',
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () {
                                          setState(() {
                                            _areaCtrl.clear();
                                            _areaFilter = '';
                                            _applyFilter();
                                          });
                                        },
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // â”€â”€ Section header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

                  // â”€â”€ Professional cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                            Text(
                                _searchCtrl.text.trim().isEmpty
                                    ? 'No professionals found'
                                    : 'Currently Not available',
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
                              isFavorite: _favoriteIds.contains(pro.uid),
                              onViewProfile: () => Navigator.pushNamed(
                                context,
                                '/professional-profile',
                                arguments: {'uid': pro.uid},
                              ),
                              onFavorite: () => _toggleFavorite(pro),
                              onComplaint: () => _submitComplaint(pro),
                              onReferral: () => _createReferral(pro),
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

                  const SliverToBoxAdapter(child: SizedBox(height: 118)),
                ],
              ),
            ),
    );
  }
}

// â”€â”€ Category Chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// â”€â”€ Professional Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SearchSuggestion {
  final String label;
  final String? serviceKey;
  final String? professionalUid;
  final int matchCount;
  final int popularity;

  const _SearchSuggestion({
    required this.label,
    this.serviceKey,
    this.professionalUid,
    required this.matchCount,
    this.popularity = 0,
  });
}

class _HowToUseStrip extends StatelessWidget {
  const _HowToUseStrip();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _HowToStepData(
        number: '1',
        title: 'Type service',
        icon: Icons.search_rounded,
        color: Color(0xFFFFC857),
      ),
      _HowToStepData(
        number: '2',
        title: 'Select professional',
        icon: Icons.engineering_rounded,
        color: Color(0xFF4FD1C5),
      ),
      _HowToStepData(
        number: '3',
        title: 'Contact',
        icon: Icons.chat_rounded,
        color: Color(0xFF7C9DFF),
      ),
    ];

    return SizedBox(
      height: 54,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(child: _HowToStep(data: steps[i])),
            if (i != steps.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _HowToStepData {
  final String number;
  final String title;
  final IconData icon;
  final Color color;

  const _HowToStepData({
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
  });
}

class _HowToStep extends StatelessWidget {
  final _HowToStepData data;

  const _HowToStep({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: AppColors.primaryDark, size: 14),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${data.number}:${data.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerActionBar extends StatelessWidget {
  final int favoriteCount;
  final VoidCallback onAutoMatch;
  final VoidCallback onPostJob;
  final VoidCallback onEstimator;
  final VoidCallback onJobs;
  final VoidCallback onSaved;
  final VoidCallback onReferral;

  const _CustomerActionBar({
    required this.favoriteCount,
    required this.onAutoMatch,
    required this.onPostJob,
    required this.onEstimator,
    required this.onJobs,
    required this.onSaved,
    required this.onReferral,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.divider)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _BottomAction(
                label: 'Match',
                icon: Icons.auto_awesome_rounded,
                onTap: onAutoMatch,
                highlighted: true,
              ),
              _BottomAction(
                label: 'AI',
                icon: Icons.psychology_rounded,
                onTap: onEstimator,
              ),
              _BottomAction(
                label: 'Post Job',
                icon: Icons.post_add_rounded,
                onTap: onPostJob,
              ),
              _BottomAction(
                label: 'My Jobs',
                icon: Icons.work_history_rounded,
                onTap: onJobs,
              ),
              _BottomAction(
                label: favoriteCount > 0 ? 'Saved $favoriteCount' : 'Saved',
                icon: Icons.bookmark_rounded,
                onTap: onSaved,
              ),
              _BottomAction(
                label: 'Referral',
                icon: Icons.card_giftcard_rounded,
                onTap: onReferral,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  const _BottomAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.primary : AppColors.textSecondary;
    return SizedBox(
      width: 76,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final ProfessionalModel professional;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onViewProfile;
  final VoidCallback? onFavorite;
  final VoidCallback? onComplaint;
  final VoidCallback? onReferral;
  final bool isFavorite;

  const _ProfessionalCard({
    required this.professional,
    this.onCall,
    this.onWhatsApp,
    this.onViewProfile,
    this.onFavorite,
    this.onComplaint,
    this.onReferral,
    this.isFavorite = false,
  });

  String _serviceLabel(String key) {
    return ServiceLabels.getName(key);
  }

  List<String> _passportBadges() {
    final badges = <String>[];
    if (professional.isFeatured) badges.add('Featured');
    if (professional.trustScore >= 85) badges.add('Reliable');
    if (professional.isAvailable) badges.add('Fast Responder');
    if (professional.rating >= 4.5 && professional.totalRatings >= 3) {
      badges.add('Top Rated');
    }
    if (professional.completedJobs >= 10) badges.add('Repeat Choice');
    if (badges.isEmpty) badges.add('Verified Profile');
    return badges.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = professional.isAvailable;
    final badges = _passportBadges();
    final package = professional.servicePackages.isNotEmpty
        ? professional.servicePackages.first
        : null;
    final packageTitle = package?['title']?.toString() ?? '';
    final packagePrice = package?['price']?.toString() ?? '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.09),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
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
                      width: 62,
                      height: 62,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.accent,
                            AppColors.star.withOpacity(0.9),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.24),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                                professional.isFeatured
                                    ? '${professional.name}  Featured'
                                    : professional.name,
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
                                    ? const Color(0xFFE6F6EF)
                                    : const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isAvailable
                                      ? AppColors.success
                                      : AppColors.divider,
                                ),
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
                            IconButton(
                              tooltip: isFavorite ? 'Remove saved' : 'Save',
                              onPressed: onFavorite,
                              icon: Icon(
                                isFavorite
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: professional.serviceTypes.take(3).map((s) {
                            final label = EnglishText.sanitize(
                              _serviceLabel(s),
                              fallback: 'Service',
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3C4),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.accent),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: badges
                              .map(
                                (badge) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF2FA),
                                    borderRadius: BorderRadius.circular(999),
                                    border:
                                        Border.all(color: AppColors.divider),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.star_rounded,
                      value: professional.ratingText,
                      label: 'Rating',
                      color: AppColors.star,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.near_me,
                      value: professional.distanceText,
                      label: 'Distance',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.verified_user_outlined,
                      value: '${professional.trustScore}%',
                      label: 'Trust',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              if (professional.address.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place,
                        size: 14, color: AppColors.textLight),
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
              if (packageTitle.isNotEmpty || packagePrice.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3C4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: Text(
                    '${packageTitle.isEmpty ? 'Service Package' : packageTitle}'
                    '${packagePrice.isEmpty ? '' : ' - PKR $packagePrice'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                      background: isAvailable ? AppColors.primary : Colors.grey,
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
                        Row(
                          children: [
                            Expanded(child: buttons[2]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CardActionButton(
                                label: 'Refer',
                                icon: Icons.card_giftcard_rounded,
                                onPressed: onReferral,
                                foreground: AppColors.primary,
                                outlined: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _CardActionButton(
                                label: 'Complaint',
                                icon: Icons.report_problem_outlined,
                                onPressed: onComplaint,
                                foreground: AppColors.error,
                                outlined: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: buttons[0]),
                          const SizedBox(width: 8),
                          Expanded(child: buttons[1]),
                          const SizedBox(width: 8),
                          Expanded(child: buttons[2]),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _CardActionButton(
                              label: 'Refer',
                              icon: Icons.card_giftcard_rounded,
                              onPressed: onReferral,
                              foreground: AppColors.primary,
                              outlined: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CardActionButton(
                              label: 'Complaint',
                              icon: Icons.report_problem_outlined,
                              onPressed: onComplaint,
                              foreground: AppColors.error,
                              outlined: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
