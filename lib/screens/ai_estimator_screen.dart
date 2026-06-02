import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class AiEstimatorScreen extends StatefulWidget {
  const AiEstimatorScreen({super.key});

  @override
  State<AiEstimatorScreen> createState() => _AiEstimatorScreenState();
}

class _AiEstimatorScreenState extends State<AiEstimatorScreen> {
  final _api = ApiService();
  final _issueCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  XFile? _photo;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _issueCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (picked != null && mounted) setState(() => _photo = picked);
  }

  Future<void> _estimate() async {
    final issue = _issueCtrl.text.trim();
    final area = _areaCtrl.text.trim();
    if (issue.length < 4) {
      setState(() => _error = 'Please describe the issue first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    final prompt = [
      'Issue: $issue',
      if (area.isNotEmpty) 'Customer area: $area',
      if (_photo != null)
        'Photo reference attached by customer. Use the written issue details for estimate.',
      'Return service type, expected price range in PKR, urgency, required material, and next step.',
    ].join('\n');
    final res = await _api.recommendService(prompt);
    if (!mounted) return;
    if (res['success'] == true && res['data'] is Map) {
      setState(() {
        _result = Map<String, dynamic>.from(res['data'] as Map);
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message']?.toString() ??
            'Estimator is unavailable. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = (_result?['serviceType'] ?? 'service').toString();
    final min = _result?['priceMin'];
    final max = _result?['priceMax'];
    final advice = (_result?['advice'] ??
            'Post a job or contact a nearby professional for final pricing.')
        .toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Service Estimator'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get a smart estimate before booking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Describe the issue using text. You can add a photo reference and area to improve the estimate.',
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _issueCtrl,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Issue details',
              hintText:
                  'Example: Water is leaking under the kitchen sink and the pipe looks broken.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _areaCtrl,
            decoration: const InputDecoration(
              labelText: 'Area or city',
              hintText: 'Example: Lahore, DHA, Saddar',
              prefixIcon: Icon(Icons.location_city_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(_photo == null ? 'Add photo reference' : 'Photo added'),
          ),
          const SizedBox(height: 8),
          const Text(
            'For voice input, use your phone keyboard microphone and dictate the issue in this box.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _estimate,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_loading ? 'Estimating...' : 'Estimate Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimate Result',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ResultRow('Service type', service.replaceAll('_', ' ')),
                  _ResultRow(
                    'Expected price',
                    min != null && max != null
                        ? 'PKR $min - $max'
                        : 'Professional will confirm',
                  ),
                  _ResultRow('Urgency', _urgencyFromAdvice(advice)),
                  _ResultRow('Material', _materialFromAdvice(advice)),
                  const SizedBox(height: 8),
                  Text(
                    advice,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Find Professionals'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _urgencyFromAdvice(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('urgent') || lower.contains('immediate')) return 'High';
    if (lower.contains('same day') || lower.contains('soon')) return 'Medium';
    return 'Normal';
  }

  String _materialFromAdvice(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('pipe')) return 'Pipe or fitting may be needed';
    if (lower.contains('wire') || lower.contains('switch')) {
      return 'Electrical parts may be needed';
    }
    if (lower.contains('gas')) return 'Technician will inspect material';
    return 'Professional will confirm after inspection';
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
