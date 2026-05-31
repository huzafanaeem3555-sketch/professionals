import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/location_service.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/location_map_picker.dart';

class ProfessionalSetupScreen extends StatefulWidget {
  const ProfessionalSetupScreen({super.key});

  @override
  State<ProfessionalSetupScreen> createState() =>
      _ProfessionalSetupScreenState();
}

class _ProfessionalSetupScreenState extends State<ProfessionalSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _manualLocationCtrl = TextEditingController();
  final _customServiceCtrl = TextEditingController();
  final _services = <String>{};
  final _customServices = <String>{};

  double _lat = 0;
  double _lng = 0;
  String _address = '';
  bool _saving = false;
  bool _loadingLocation = true;
  String _photoURL = '';
  String? _photoBase64;
  final _brochureUrls = <String>[];
  final _brochureBase64 = <String>[];

  final _serviceKeys =
      AppStrings.serviceCategories.map((c) => c['key'] as String).toList();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = await StorageService.getUid() ?? user.uid;
      _nameCtrl.text = user.displayName ?? '';
      final pro = await FirebaseService().getProfessionalById(uid);
      if (pro != null && mounted) {
        _nameCtrl.text = pro['name']?.toString() ?? user.displayName ?? '';
        _phoneCtrl.text =
            pro['phone']?.toString() ?? pro['phoneNumber']?.toString() ?? '';
        _photoURL = (pro['photoURL'] ??
                pro['photoUrl'] ??
                pro['profileImage'] ??
                pro['imageUrl'] ??
                '')
            .toString();
        _experienceCtrl.text = pro['experienceYears']?.toString() ?? '';
        final brochureImages = pro['brochureImages'] ?? pro['bannerImages'];
        if (brochureImages is List) {
          _brochureUrls
            ..clear()
            ..addAll(brochureImages.map((e) => e.toString()));
        }
        final svc = pro['services'];
        if (svc is List) {
          _services.clear();
          _services.addAll(svc.map((e) => e.toString()));
        }
        final customSvc = pro['customServices'];
        if (customSvc is List) {
          _customServices.clear();
          _customServices.addAll(customSvc.map((e) => e.toString()));
        }
        final loc = pro['location'];
        if (loc is Map) {
          _lat = (loc['lat'] ?? 0).toDouble();
          _lng = (loc['lng'] ?? 0).toDouble();
          _address = loc['address']?.toString() ?? '';
          _manualLocationCtrl.text = _address;
        }
      }
    }
    await _fetchGps();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _experienceCtrl.dispose();
    _manualLocationCtrl.dispose();
    _customServiceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 1200,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  Future<void> _pickBrochureImages() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (picked.isEmpty) return;
    final remaining = 6 - (_brochureUrls.length + _brochureBase64.length);
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 brochure images allowed')),
      );
      return;
    }
    final selected = picked.take(remaining);
    final encoded = <String>[];
    for (final image in selected) {
      encoded.add(base64Encode(await image.readAsBytes()));
    }
    if (!mounted) return;
    setState(() => _brochureBase64.addAll(encoded));
  }

  List<String> get _allBrochureImages => [
        ..._brochureUrls,
        ..._brochureBase64.map((e) => 'data:image/jpeg;base64,$e'),
      ];

  Future<void> _fetchGps() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      _lat = pos.latitude;
      _lng = pos.longitude;
      _address = await LocationService().getAddressFromCoordinates(_lat, _lng);
      if (mounted) setState(() => _loadingLocation = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.warning,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _fetchGps,
            ),
          ),
        );
      }
    }
  }

  void _onMapMoved(LatLng pos) async {
    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
      _loadingLocation = true;
    });
    final addr = await LocationService().getAddressFromCoordinates(
      pos.latitude,
      pos.longitude,
    );
    if (mounted) {
      setState(() {
        _address = addr;
        _loadingLocation = false;
      });
    }
  }

  void _addCustomService() {
    final raw = _customServiceCtrl.text.trim();
    if (raw.isEmpty) return;
    final key = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    setState(() {
      _customServices.add(key);
      _customServiceCtrl.clear();
    });
  }

  String _serviceLabel(String key) {
    final cat = AppStrings.serviceCategories.firstWhere(
      (c) => c['key'] == key,
      orElse: () => {'name': key.replaceAll('_', ' '), 'icon': '✨'},
    );
    return '${cat['icon']} ${cat['name']}';
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = FirebaseService.normalizePhone(_phoneCtrl.text.trim());
    final experienceYears = int.tryParse(_experienceCtrl.text.trim()) ?? 0;

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name and phone number')),
      );
      return;
    }
    if (_services.isEmpty && _customServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one service')),
      );
      return;
    }
    if (_lat == 0 && _lng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set your location — enable GPS or tap the map'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final uploadedBrochureUrls = <String>[..._brochureUrls];
    for (final image in _brochureBase64) {
      final upload = await ApiService().uploadImgBbImage(
        image,
        namePrefix: 'professional_brochure',
      );
      final uploadedUrl =
          upload['data'] is Map ? (upload['data']['url'] ?? '').toString() : '';
      if (uploadedUrl.isNotEmpty) {
        uploadedBrochureUrls.add(uploadedUrl);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              upload['message']?.toString() ?? 'Brochure upload failed',
            ),
          ),
        );
      }
    }
    _brochureUrls
      ..clear()
      ..addAll(uploadedBrochureUrls);
    _brochureBase64.clear();

    var success = await FirebaseService().saveProfessional({
      'phone': phone,
      'name': name,
      'services': _services.toList(),
      'customServices': _customServices.toList(),
      'photoURL': _photoURL,
      'brochureImages': _brochureUrls,
      'experienceYears': experienceYears,
      'location': {
        'lat': _lat,
        'lng': _lng,
        'address': _manualLocationCtrl.text.trim().isNotEmpty
            ? _manualLocationCtrl.text.trim()
            : _address,
      },
      'isAvailable': true,
    });

    if (success && _photoBase64 != null) {
      final upload = await ApiService().uploadProfilePhoto(_photoBase64!);
      final uploadedUrl = upload['data'] is Map
          ? upload['data']['photoURL']?.toString() ?? ''
          : '';
      if (uploadedUrl.isNotEmpty) {
        _photoURL = uploadedUrl;
        if (mounted) setState(() => _photoURL = uploadedUrl);
        success = await FirebaseService().saveProfessional({
          'phone': phone,
          'name': name,
          'services': _services.toList(),
          'customServices': _customServices.toList(),
          'photoURL': _photoURL,
          'brochureImages': _brochureUrls,
          'experienceYears': experienceYears,
          'location': {
            'lat': _lat,
            'lng': _lng,
            'address': _manualLocationCtrl.text.trim().isNotEmpty
                ? _manualLocationCtrl.text.trim()
                : _address,
          },
          'isAvailable': true,
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(upload['message']?.toString() ?? 'Photo upload failed')),
        );
      }
    }

    if (!mounted) return;

    if (success) {
      await StorageService.setProfessionalPhone(phone);
      await StorageService.setRole('professional');
      final details = await StorageService.getUserDetails();
      await StorageService.setUserDetails(
        name: name,
        email: details['email'] ?? '',
        photo: details['photo'] ?? _photoURL,
        phone: phone,
        idToken: details['idToken'],
      );
      final gender = (await StorageService.getGender() ?? 'male').toLowerCase();
      final status =
          (await StorageService.getVerificationStatus() ?? 'verified')
              .toLowerCase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved!'),
          backgroundColor: AppColors.success,
        ),
      );
      if (gender == 'female' && status != 'verified') {
        Navigator.pushReplacementNamed(
          context,
          '/gender-verification',
          arguments: 'professional',
        );
        return;
      }
      Navigator.pushReplacementNamed(context, '/professional-home');
    } else {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Save failed. Start backend (npm start) or open Firebase rules for write access.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional Profile'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Complete Your Profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Phone & location are visible to customers — no login needed',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.surfaceLight,
                    backgroundImage: _photoBase64 != null
                        ? MemoryImage(base64Decode(_photoBase64!))
                        : (_photoURL.isNotEmpty
                            ? NetworkImage(_photoURL)
                            : null) as ImageProvider?,
                    child: _photoBase64 == null && _photoURL.isEmpty
                        ? const Icon(Icons.person,
                            size: 42, color: AppColors.primary)
                        : null,
                  ),
                  IconButton.filled(
                    onPressed: _saving ? null : _pickProfilePhoto,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    tooltip: 'Upload profile photo',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _BrochurePicker(
              images: _allBrochureImages,
              saving: _saving,
              onAdd: _pickBrochureImages,
              onRemove: (index) {
                setState(() {
                  if (index < _brochureUrls.length) {
                    _brochureUrls.removeAt(index);
                  } else {
                    _brochureBase64.removeAt(index - _brochureUrls.length);
                  }
                });
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _experienceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Experience Years',
                hintText: 'Example: 3',
                prefixIcon: Icon(Icons.work_history_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualLocationCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Location Text (optional)',
                hintText: 'Area / landmark',
                prefixIcon: Icon(Icons.edit_location_alt_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Services *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _serviceKeys.map((key) {
                final selected = _services.contains(key);
                return FilterChip(
                  label: Text(_serviceLabel(key)),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _services.add(key);
                    } else {
                      _services.remove(key);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customServiceCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Custom service e.g. Solar Panel',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCustomService(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addCustomService,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add custom service',
                ),
              ],
            ),
            if (_customServices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: _customServices
                      .map(
                        (s) => Chip(
                          label: Text(_serviceLabel(s)),
                          onDeleted: () =>
                              setState(() => _customServices.remove(s)),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Your Location *',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadingLocation ? null : _fetchGps,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('GPS'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingLocation)
              const LinearProgressIndicator()
            else
              Text(
                _address.isNotEmpty
                    ? _address
                    : 'Tap map or GPS to set location',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 8),
            LocationMapPicker(
              lat: _lat,
              lng: _lng,
              onLocationChanged: _onMapMoved,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save & Open Dashboard',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrochurePicker extends StatelessWidget {
  final List<String> images;
  final bool saving;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _BrochurePicker({
    required this.images,
    required this.saving,
    required this.onAdd,
    required this.onRemove,
  });

  ImageProvider _imageProvider(String value) {
    if (value.startsWith('data:image')) {
      return MemoryImage(base64Decode(value.split(',').last));
    }
    return NetworkImage(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Brochure / Card / Banner',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: saving ? null : onAdd,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload service cards, banners, rate cards or work brochures. Customers will see these on your profile.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 148,
                        height: 104,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: _imageProvider(images[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: InkWell(
                          onTap: saving ? null : () => onRemove(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
