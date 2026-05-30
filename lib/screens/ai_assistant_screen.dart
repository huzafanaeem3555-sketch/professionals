import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class AIAssistantScreen extends StatefulWidget {
  final bool embedded;
  const AIAssistantScreen({super.key, this.embedded = false});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMsg> _messages = [];
  bool _isLoading = false;
  final List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(_ChatMsg(
      text: 'Assalam-o-Alaikum! 👋\n\nMain Service Connect ka AI Assistant hoon (Groq llama3 powered).\n\nMain aapki help kar sakta hoon:\n• Sahi service type find karna\n• EasyPaisa payment process samajhna\n• Booking related questions\n• Professionals ke baare mein\n\nKya poochna hai?',
      isAI: true,
      time: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.groqPurple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('llama-3.3-70b (Groq)', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.groqPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _history.clear();
                _messages.add(_ChatMsg(
                  text: 'Chat cleared! Koi naya sawal puchein.',
                  isAI: true,
                  time: DateTime.now(),
                ));
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick suggestions
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip('💡 Recommend a service', () => _quickSend('Meri nali band ho gayi hai, kya karoon?')),
                  _QuickChip('💸 EasyPaisa kaise karein?', () => _quickSend('EasyPaisa se payment kaise karte hain?')),
                  _QuickChip('📋 Booking process?', () => _quickSend('Professional hire karne ka process kya hai?')),
                  _QuickChip('⭐ Rating system?', () => _quickSend('Rating kaise dete hain?')),
                ],
              ),
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(msg: _messages[index]);
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Kuch bhi puchein...',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isLoading ? Colors.grey : AppColors.groqPurple,
                        shape: BoxShape.circle,
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 22),
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

  void _quickSend(String text) {
    _controller.text = text;
    _sendMessage();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMsg(text: text, isAI: false, time: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    _history.add({'role': 'user', 'content': text});

    try {
      final response = await _api.sendAIMessage(text, _history);
      final reply = response['data']['reply'] ?? 'Sorry, koi response nahi mila.';

      _history.add({'role': 'assistant', 'content': reply});

      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(text: reply, isAI: true, time: DateTime.now()));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(
            text: 'AI assistant abhi unavailable hai. Internet connection check karein.',
            isAI: true,
            time: DateTime.now(),
          ));
          _isLoading = false;
        });
      }
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
}

class _ChatMsg {
  final String text;
  final bool isAI;
  final DateTime time;

  _ChatMsg({required this.text, required this.isAI, required this.time});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMsg msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: msg.isAI ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (msg.isAI)
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 4),
                child: Text('🤖 AI Assistant',
                    style: TextStyle(fontSize: 11, color: AppColors.groqPurple, fontWeight: FontWeight.w600)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isAI ? Colors.white : AppColors.groqPurple,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: msg.isAI ? const Radius.circular(4) : const Radius.circular(18),
                  bottomRight: msg.isAI ? const Radius.circular(18) : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: msg.isAI ? AppColors.textPrimary : Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                DateFormat('hh:mm a').format(msg.time),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🤖 ', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            const SizedBox(
              width: 40,
              height: 20,
              child: _DotsAnimation(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  const _DotsAnimation();

  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final val = (_controller.value * 3).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == val ? AppColors.groqPurple : AppColors.groqPurple.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          )),
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.groqPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.groqPurple.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.groqPurple, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
