import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String? bookingId;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    this.bookingId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _firebase = FirebaseService();

  String _myId = '';
  bool _chatEnabled = false;
  bool _loading = true;
  String? _statusMessage;
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<DatabaseEvent>? _childAddedSub;
  StreamSubscription<DatabaseEvent>? _childChangedSub;

  late AnimationController _sendBtnCtrl;
  late Animation<double> _sendBtnScale;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _sendBtnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _sendBtnScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _sendBtnCtrl, curve: Curves.elasticOut));

    _messageController.addListener(() {
      final has = _messageController.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
        has ? _sendBtnCtrl.forward() : _sendBtnCtrl.reverse();
      }
    });

    _initChat();
  }

  @override
  void dispose() {
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _sendBtnCtrl.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    _myId = await StorageService.getUid() ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';

    if (_myId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage =
              'Could not identify your account. Please log in again.';
        });
      }
      return;
    }

    // Allow chat — check booking confirmation
    _chatEnabled = await _firebase.isChatAllowed(
      myId: _myId,
      otherUserId: widget.otherUserId,
      bookingId: widget.bookingId,
    );

    if (!_chatEnabled) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage =
              'Chat opens after booking is confirmed by both parties.';
        });
      }
      return;
    }

    // Load existing messages
    final ref = _firebase.getChatMessagesRef(
      _myId,
      widget.otherUserId,
      bookingId: widget.bookingId,
    );

    try {
      final snap = await ref.get();
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        data.forEach((k, v) {
          final m = Map<String, dynamic>.from(v as Map);
          m['id'] = k;
          _messages.add(m);
        });
        _messages.sort(
            (a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
      }
    } catch (_) {}

    // Listen for new messages
    _childAddedSub = ref.onChildAdded.listen((event) {
      if (!event.snapshot.exists || !mounted) return;
      final m = Map<String, dynamic>.from(event.snapshot.value as Map);
      m['id'] = event.snapshot.key;
      final exists = _messages.any((x) => x['id'] == m['id']);
      if (!exists) {
        setState(() => _messages.add(m));
        _scrollToBottom();
      }
    });

    if (mounted) {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    if (!_chatEnabled) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final success = await _firebase.sendMessage(
      _myId,
      widget.otherUserId,
      text,
      bookingId: widget.bookingId,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: AppColors.error),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  int? _messageTimestamp(Map<String, dynamic> msg) {
    final ts = msg['timestamp'];
    if (ts is int) return ts;
    if (ts is double) return ts.toInt();
    return null;
  }

  String _formatDate(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('MMM d, yyyy').format(dt);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    // Group messages by date
    List<dynamic> groupedMessages = [];
    String? lastDate;
    for (final msg in _messages) {
      final ts = _messageTimestamp(msg);
      if (ts != null) {
        final dateStr = _formatDate(ts);
        if (dateStr != lastDate) {
          groupedMessages.add({'_type': 'date', 'label': dateStr});
          lastDate = dateStr;
        }
      }
      groupedMessages.add(msg);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Status banner
          if (_statusMessage != null) _buildStatusBanner(),

          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : groupedMessages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: groupedMessages.length,
                        itemBuilder: (ctx, i) {
                          final item = groupedMessages[i];
                          if (item is Map && item['_type'] == 'date') {
                            return _buildDateDivider(item['label']);
                          }
                          final msg = item as Map<String, dynamic>;
                          final isMe = msg['senderId'] == _myId;
                          final ts = _messageTimestamp(msg);
                          final timeStr = ts != null
                              ? DateFormat('hh:mm a').format(
                                  DateTime.fromMillisecondsSinceEpoch(ts))
                              : '';
                          return _MessageBubble(
                            text: msg['text']?.toString() ?? '',
                            isMe: isMe,
                            time: timeStr,
                            initials: _initials(widget.otherUserName),
                          );
                        },
                      ),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: widget.otherUserPhoto != null &&
                    widget.otherUserPhoto!.isNotEmpty
                ? ClipOval(
                    child: Image.network(widget.otherUserPhoto!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                            child: Text(_initials(widget.otherUserName),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)))))
                : Center(
                    child: Text(
                      _initials(widget.otherUserName),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    const Text('Online',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_rounded, color: Colors.white),
          onPressed: () {},
          tooltip: 'Call',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onPressed: () {},
          tooltip: 'More',
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warning.withOpacity(0.12),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primaryLight.withOpacity(0.1)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No messages yet',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Start the conversation!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
              child:
                  Divider(color: Colors.grey.withOpacity(0.3), thickness: 1)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)
              ],
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Divider(color: Colors.grey.withOpacity(0.3), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, -3))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        enabled: _chatEnabled,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: _chatEnabled
                              ? 'Type a message...'
                              : 'Chat locked',
                          hintStyle: const TextStyle(
                              color: AppColors.textLight, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            ScaleTransition(
              scale: _sendBtnScale,
              child: GestureDetector(
                onTap: _chatEnabled ? _sendMessage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: _hasText && _chatEnabled
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _hasText && _chatEnabled
                        ? null
                        : AppColors.surfaceLight,
                    shape: BoxShape.circle,
                    boxShadow: _hasText && _chatEnabled
                        ? [
                            BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: _hasText && _chatEnabled
                        ? Colors.white
                        : AppColors.textLight,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final String initials;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.time,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar
          if (!isMe) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary]),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                      color: isMe
                          ? AppColors.primary.withOpacity(0.2)
                          : Colors.black.withOpacity(0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.4),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                              color:
                                  isMe ? Colors.white60 : AppColors.textLight,
                              fontSize: 10),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.done_all_rounded,
                              size: 12, color: Colors.white60),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // My avatar spacer
          if (isMe) ...[
            const SizedBox(width: 6),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.primaryLight]),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child:
                    Icon(Icons.person_rounded, color: Colors.white, size: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
