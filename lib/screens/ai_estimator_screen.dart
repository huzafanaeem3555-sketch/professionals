import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../utils/contact_actions.dart';
import '../utils/constants.dart';

class AiEstimatorScreen extends StatefulWidget {
  const AiEstimatorScreen({super.key});

  @override
  State<AiEstimatorScreen> createState() => _AiEstimatorScreenState();
}

class _AiEstimatorScreenState extends State<AiEstimatorScreen> {
  final _api = ApiService();
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_AiMessage> _messages = [];
  final List<Map<String, String>> _history = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _AiMessage.assistant(
        'Hello! Tell me your problem in any language. I will guide you and show matching HirePro professionals with WhatsApp contact.',
      ),
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = (quickText ?? _messageCtrl.text).trim();
    if (text.isEmpty || _loading) return;

    _messageCtrl.clear();
    setState(() {
      _messages.add(_AiMessage.customer(text));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final response = await _api.sendAIMessage(text, _history);
      final data = Map<String, dynamic>.from(response['data'] ?? {});
      final reply = (data['reply'] ??
              'I could not generate a response. Please try again.')
          .toString();
      final professionals = (data['professionals'] is List)
          ? (data['professionals'] as List)
              .whereType<Map>()
              .map((item) => _SuggestedProfessional.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .where((pro) => pro.uid.isNotEmpty)
              .toList()
          : <_SuggestedProfessional>[];

      _history.add({'role': 'user', 'content': text});
      _history.add({'role': 'assistant', 'content': reply});
      if (_history.length > 10) {
        _history.removeRange(0, _history.length - 10);
      }

      if (!mounted) return;
      setState(() {
        _messages.add(
          _AiMessage.assistant(
            reply,
            matchedService: data['matchedService']?.toString(),
            professionals: professionals,
          ),
        );
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _AiMessage.assistant(
            'AI assistant is unavailable right now. Please check your internet connection and try again.',
          ),
        );
        _loading = false;
      });
    }
  }

  Future<void> _openWhatsApp(_SuggestedProfessional pro) async {
    if (pro.phone.isEmpty) return;

    final user = await StorageService.getUserDetails();
    final customerId = await StorageService.getCustomerId();
    final customerName = user['name']?.trim().isNotEmpty == true
        ? user['name']!.trim()
        : 'Customer';
    final customerPhone = user['phone']?.trim().isNotEmpty == true
        ? user['phone']!.trim()
        : 'Not shared';
    final serviceType =
        pro.services.isNotEmpty ? pro.services.first : 'service';

    await _api.saveContactLeadPublic(
      targetUserId: pro.uid,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: 'Contacted from AI assistant',
      serviceType: serviceType,
      contactMethod: 'whatsapp',
    );

    final uri = contactUriFor(
      method: ContactMethod.whatsapp,
      phoneNumber: pro.phone,
      message:
          'Hello ${pro.name}, I found your profile on HirePro AI for $serviceType. Please guide me about price and availability.',
    );
    await launchContactUri(uri);
  }

  void _openProfile(_SuggestedProfessional pro) {
    Navigator.pushNamed(
      context,
      '/professional-profile',
      arguments: {'uid': pro.uid},
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('HirePro AI'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: () {
              setState(() {
                _history.clear();
                _messages
                  ..clear()
                  ..add(
                    _AiMessage.assistant(
                      'Chat cleared. Ask me about any home, office, or business service problem.',
                    ),
                  );
              });
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ask your service problem',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'AI replies in your language and suggests matching professionals below the answer.',
                  style:
                      TextStyle(color: AppColors.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickChip('Pani leak ho raha hai', _sendMessage),
                    _QuickChip('AC cooling problem', _sendMessage),
                    _QuickChip('Office wiring issue', _sendMessage),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return const _TypingBubble();
                final message = _messages[index];
                return _MessageBubble(
                  message: message,
                  onWhatsApp: _openWhatsApp,
                  onProfile: _openProfile,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.divider)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type your issue...',
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: FilledButton(
                      onPressed: _loading ? null : () => _sendMessage(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMessage {
  final String text;
  final bool fromCustomer;
  final String? matchedService;
  final List<_SuggestedProfessional> professionals;

  const _AiMessage({
    required this.text,
    required this.fromCustomer,
    this.matchedService,
    this.professionals = const [],
  });

  factory _AiMessage.customer(String text) =>
      _AiMessage(text: text, fromCustomer: true);

  factory _AiMessage.assistant(
    String text, {
    String? matchedService,
    List<_SuggestedProfessional> professionals = const [],
  }) =>
      _AiMessage(
        text: text,
        fromCustomer: false,
        matchedService: matchedService,
        professionals: professionals,
      );
}

class _SuggestedProfessional {
  final String uid;
  final String name;
  final String phone;
  final String photoURL;
  final List<String> services;
  final double rating;
  final int totalRatings;
  final int completedJobs;
  final int reliabilityScore;
  final double? distance;
  final bool isFeatured;

  const _SuggestedProfessional({
    required this.uid,
    required this.name,
    required this.phone,
    required this.photoURL,
    required this.services,
    required this.rating,
    required this.totalRatings,
    required this.completedJobs,
    required this.reliabilityScore,
    required this.distance,
    required this.isFeatured,
  });

  factory _SuggestedProfessional.fromJson(Map<String, dynamic> json) {
    return _SuggestedProfessional(
      uid: (json['uid'] ?? '').toString(),
      name: _cleanText((json['name'] ?? 'Professional').toString()),
      phone: (json['phone'] ?? json['phoneNumber'] ?? '').toString(),
      photoURL: (json['photoURL'] ?? '').toString(),
      services: (json['services'] is List)
          ? (json['services'] as List)
              .map((item) => _cleanText(item.toString()))
              .where((item) => item.isNotEmpty)
              .toList()
          : const [],
      rating: _toDouble(json['rating']),
      totalRatings: _toInt(json['totalRatings']),
      completedJobs: _toInt(json['completedJobs']),
      reliabilityScore: _toInt(json['reliabilityScore']),
      distance: json['distance'] == null ? null : _toDouble(json['distance']),
      isFeatured: json['isFeatured'] == true,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _AiMessage message;
  final Future<void> Function(_SuggestedProfessional pro) onWhatsApp;
  final void Function(_SuggestedProfessional pro) onProfile;

  const _MessageBubble({
    required this.message,
    required this.onWhatsApp,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isCustomer = message.fromCustomer;
    return Align(
      alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: isCustomer ? null : double.infinity,
        constraints: BoxConstraints(
          maxWidth: isCustomer
              ? MediaQuery.of(context).size.width * 0.82
              : double.infinity,
        ),
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment:
              isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: isCustomer ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    isCustomer ? null : Border.all(color: AppColors.divider),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isCustomer ? Colors.white : AppColors.textPrimary,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!isCustomer && message.matchedService?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Suggested service: ${message.matchedService!.replaceAll('_', ' ')}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            if (!isCustomer && message.professionals.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Matching professionals',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              ...message.professionals.map(
                (pro) => _ProfessionalSuggestionCard(
                  pro: pro,
                  onWhatsApp: () => onWhatsApp(pro),
                  onProfile: () => onProfile(pro),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfessionalSuggestionCard extends StatelessWidget {
  final _SuggestedProfessional pro;
  final VoidCallback onWhatsApp;
  final VoidCallback onProfile;

  const _ProfessionalSuggestionCard({
    required this.pro,
    required this.onWhatsApp,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final serviceText = pro.services.isEmpty
        ? 'Service professional'
        : pro.services.take(3).join(' | ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceLight,
                backgroundImage:
                    pro.photoURL.isEmpty ? null : NetworkImage(pro.photoURL),
                child: pro.photoURL.isEmpty
                    ? Text(
                        pro.name.isEmpty ? 'P' : pro.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pro.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (pro.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Top',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID: ${pro.uid}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      serviceText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(Icons.star_rounded, pro.rating.toStringAsFixed(1)),
              _MetaPill(Icons.reviews_rounded, '${pro.totalRatings} reviews'),
              _MetaPill(Icons.task_alt_rounded, '${pro.completedJobs} jobs'),
              if (pro.distance != null)
                _MetaPill(Icons.near_me_rounded, '${pro.distance} km'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onProfile,
                  icon: const Icon(Icons.person_rounded, size: 18),
                  label: const Text('Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: pro.phone.isEmpty ? null : onWhatsApp,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final Future<void> Function(String text) onTap;

  const _QuickChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: () => onTap(label),
      label: Text(label),
      labelStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      avatar: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
      backgroundColor: AppColors.surfaceLight,
      side: const BorderSide(color: AppColors.divider),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'AI is thinking...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cleanText(String value) {
  return value
      .replaceAll(RegExp(r'[\u3400-\u9FFF\uF900-\uFAFF]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
