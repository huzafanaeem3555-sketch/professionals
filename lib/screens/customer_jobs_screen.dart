import 'package:flutter/material.dart';
import '../utils/snackbar_helper.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/contact_actions.dart';

class CustomerJobsScreen extends StatefulWidget {
  const CustomerJobsScreen({super.key});

  @override
  State<CustomerJobsScreen> createState() => _CustomerJobsScreenState();
}

class _CustomerJobsScreenState extends State<CustomerJobsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.getJobPosts();
    if (!mounted) return;
    setState(() {
      _jobs = res['success'] == true && res['data'] is List
          ? (res['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
      _loading = false;
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _date(dynamic value) {
    final ms = _toInt(value);
    if (ms <= 0) return 'N/A';
    return DateFormat('dd MMM yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Jobs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _jobs.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Icon(Icons.work_outline_rounded,
                            size: 64, color: AppColors.textLight),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            'No jobs posted yet',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _jobs.length,
                      itemBuilder: (context, index) {
                        final job = _jobs[index];
                        final title =
                            (job['title'] ?? job['serviceType'] ?? 'Job')
                                .toString();
                        final category = (job['serviceType'] ?? 'service')
                            .toString()
                            .replaceAll('_', ' ');
                        final status = (job['status'] ?? 'open').toString();
                        final isUrgent = job['isUrgent'] == true ||
                            job['priority']?.toString() == 'urgent';
                        final offers = _toInt(job['offerCount']);
                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.divider),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomerJobDetailsScreen(job: job),
                                ),
                              );
                              _load();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isUrgent) ...[
                                        const _StatusPill(status: 'Need Now'),
                                        const SizedBox(width: 6),
                                      ],
                                      _StatusPill(status: status),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Category: $category',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Posted: ${_date(job['createdAt'])}',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.people_alt_rounded,
                                          size: 17, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$offers applications received',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.chevron_right_rounded,
                                          color: AppColors.textLight),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class CustomerJobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const CustomerJobDetailsScreen({super.key, required this.job});

  @override
  State<CustomerJobDetailsScreen> createState() =>
      _CustomerJobDetailsScreenState();
}

class _CustomerJobDetailsScreenState extends State<CustomerJobDetailsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _offers = [];
  late Map<String, dynamic> _job;

  @override
  void initState() {
    super.initState();
    _job = Map<String, dynamic>.from(widget.job);
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _loading = true);
    final postId = _job['postId']?.toString() ?? '';
    final res =
        postId.isEmpty ? {'success': false} : await _api.getJobOffers(postId);
    if (!mounted) return;
    setState(() {
      _offers = res['success'] == true && res['data'] is List
          ? (res['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
      _loading = false;
    });
  }

  Future<void> _selectOffer(Map<String, dynamic> offer) async {
    final postId = _job['postId']?.toString() ?? '';
    final offerId = offer['offerId']?.toString() ?? '';
    if (postId.isEmpty || offerId.isEmpty) return;
    final res = await _api.selectJobOffer(postId: postId, offerId: offerId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _job['status'] = 'assigned';
        _job['selectedOfferId'] = offerId;
        _job['selectedProfessionalId'] = offer['professionalId'];
      });
      await _loadOffers();
    }
    showTimedSnackBar(
      context,
      SnackBar(
        content: Text(res['success'] == true
            ? 'Professional selected.'
            : res['message']?.toString() ?? 'Selection failed'),
        backgroundColor:
            res['success'] == true ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _updateStatus(String status) async {
    final postId = _job['postId']?.toString() ?? '';
    if (postId.isEmpty) return;
    final res = await _api.updateJobStatus(postId: postId, status: status);
    if (!mounted) return;
    if (res['success'] == true) setState(() => _job['status'] = status);
    showTimedSnackBar(
      context,
      SnackBar(
        content: Text(res['success'] == true
            ? (status == 'open'
                ? 'Job reopened for professionals.'
                : 'Job status updated.')
            : res['message']?.toString() ?? 'Status update failed'),
        backgroundColor:
            res['success'] == true ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _counterOffer(Map<String, dynamic> offer) async {
    final postId = _job['postId']?.toString() ?? '';
    final offerId = offer['offerId']?.toString() ?? '';
    if (postId.isEmpty || offerId.isEmpty) return;
    final priceCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Counter Price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Your price PKR',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message optional',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    final message = msgCtrl.text.trim();
    priceCtrl.dispose();
    msgCtrl.dispose();
    if (ok != true || price <= 0) return;
    final res = await _api.counterJobOffer(
      postId: postId,
      offerId: offerId,
      counterPrice: price,
      message: message,
    );
    if (res['success'] == true) await _loadOffers();
    if (!mounted) return;
    showTimedSnackBar(
      context,
      SnackBar(
        content: Text(res['success'] == true
            ? 'Counter price sent.'
            : res['message']?.toString() ?? 'Counter failed'),
        backgroundColor:
            res['success'] == true ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (_job['title'] ?? _job['serviceType'] ?? 'Job').toString();
    final service =
        (_job['serviceType'] ?? 'service').toString().replaceAll('_', ' ');
    final description = (_job['description'] ?? '').toString();
    final budget = (_job['budget'] ?? 0).toString();
    final status = (_job['status'] ?? 'open').toString();
    final isUrgent =
        _job['isUrgent'] == true || _job['priority']?.toString() == 'urgent';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Job Details')),
      body: RefreshIndicator(
        onRefresh: _loadOffers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isUrgent) ...[
                        const _StatusPill(status: 'Need Now'),
                        const SizedBox(width: 6),
                      ],
                      _StatusPill(status: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Category: $service',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text('Budget: PKR $budget',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(description,
                        style: const TextStyle(color: AppColors.textPrimary)),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status == 'assigned')
                        FilledButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.assignment_turned_in_rounded),
                          label: const Text('Job Assigned'),
                        ),
                      OutlinedButton.icon(
                        onPressed: status == 'open'
                            ? null
                            : () => _updateStatus('open'),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Applications / Offers',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text('${_offers.length}',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_offers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text(
                    'No professional offers yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ..._offers.map((offer) => _OfferCard(
                    offer: offer,
                    selectedOfferId: _job['selectedOfferId']?.toString() ?? '',
                    onSelect: () => _selectOffer(offer),
                    onCounter: () => _counterOffer(offer),
                  )),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final String selectedOfferId;
  final VoidCallback onSelect;
  final VoidCallback onCounter;

  const _OfferCard({
    required this.offer,
    required this.selectedOfferId,
    required this.onSelect,
    required this.onCounter,
  });

  @override
  Widget build(BuildContext context) {
    final name = offer['professionalName']?.toString() ?? 'Professional';
    final phone = offer['professionalPhone']?.toString() ?? '';
    final photo = offer['professionalPhotoURL']?.toString() ?? '';
    final service =
        (offer['serviceType'] ?? 'service').toString().replaceAll('_', ' ');
    final price = offer['price']?.toString() ?? '0';
    final counterPrice = offer['counterPrice']?.toString() ?? '';
    final message = offer['message']?.toString() ?? '';
    final customerMessage = offer['customerMessage']?.toString() ?? '';
    final status = offer['status']?.toString() ?? 'pending';
    final offerId = offer['offerId']?.toString() ?? '';
    final selected = selectedOfferId.isNotEmpty && selectedOfferId == offerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P')
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(service,
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _StatusPill(status: selected ? 'selected' : status),
            ],
          ),
          const SizedBox(height: 12),
          Text('Offered price: PKR $price',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold)),
          if (counterPrice.isNotEmpty && counterPrice != '0') ...[
            const SizedBox(height: 6),
            Text('Your counter: PKR $counterPrice',
                style: const TextStyle(
                    color: AppColors.warning, fontWeight: FontWeight.bold)),
          ],
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
          if (customerMessage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Counter note: $customerMessage',
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final contactButtons = [
                ElevatedButton.icon(
                  onPressed: phone.isEmpty
                      ? null
                      : () => launchContactUri(contactUriFor(
                            method: ContactMethod.whatsapp,
                            phoneNumber: phone,
                            message:
                                'Hello, I saw your offer on my HirePro job.',
                          )),
                  icon: const Icon(Icons.chat_rounded, color: Colors.white),
                  label: const Text('Contact on WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: phone.isEmpty
                      ? null
                      : () => launchContactUri(contactUriFor(
                            method: ContactMethod.call,
                            phoneNumber: phone,
                          )),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call'),
                ),
              ];
              final actionButtons = [
                OutlinedButton.icon(
                  onPressed: selectedOfferId.isEmpty ? onCounter : null,
                  icon: const Icon(Icons.price_change_rounded),
                  label: const Text('Counter'),
                ),
                ElevatedButton.icon(
                  onPressed: selectedOfferId.isEmpty ? onSelect : null,
                  icon: Icon(selected
                      ? Icons.assignment_turned_in_rounded
                      : Icons.check_circle_outline_rounded),
                  label: Text(selected ? 'Job Assigned' : 'Assign Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selected ? AppColors.success : AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ];
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...contactButtons.map((button) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: button,
                        )),
                    Row(
                      children: [
                        Expanded(child: actionButtons[0]),
                        const SizedBox(width: 8),
                        Expanded(child: actionButtons[1]),
                      ],
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: contactButtons[0]),
                      const SizedBox(width: 8),
                      Expanded(child: contactButtons[1]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: actionButtons[0]),
                      const SizedBox(width: 8),
                      Expanded(child: actionButtons[1]),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
