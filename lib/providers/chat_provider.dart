import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/chat_model.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final ApiService _api = ApiService();

  List<ChatMessage> _messages = [];
  List<ChatConversation> _conversations = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _messageSubscription;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  List<ChatMessage> get messages => _messages;
  List<ChatConversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load messages with specific user - with retry logic
  Future<void> loadMessages(String myUid, String otherUserId) async {
    _setLoading(true);
    _clearError();
    _retryCount = 0;
    
    try {
      await _loadMessagesWithRetry(myUid, otherUserId);
      _startListeningToMessages(myUid, otherUserId);
    } catch (e) {
      ErrorHandler.logError('loadMessages failed after retries', e);
      _setError('Failed to load chat. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadMessagesWithRetry(String myUid, String otherUserId) async {
    try {
      final ref = _firebase.getChatMessagesRef(myUid, otherUserId);
      final snapshot = await ref.get().timeout(const Duration(seconds: 10));

      _messages = [];
      if (snapshot.exists && snapshot.value != null) {
        try {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          for (final entry in data.entries) {
            try {
              final msg = Map<String, dynamic>.from(entry.value as Map);
              msg['id'] = entry.key;
              _messages.add(ChatMessage.fromMap(msg));
            } catch (e) {
              ErrorHandler.logWarning('Failed to parse message $e');
              continue;
            }
          }
          _messages.sort((a, b) => 
            (a.timestamp ?? DateTime.now()).compareTo(b.timestamp ?? DateTime.now())
          );
          ErrorHandler.logSuccess('Loaded ${_messages.length} messages');
        } catch (e) {
          ErrorHandler.logError('Error parsing messages', e);
          _messages = [];
        }
      }
      notifyListeners();
    } on TimeoutException {
      if (_retryCount < _maxRetries) {
        _retryCount++;
        ErrorHandler.logWarning('Message load timeout, retry $_retryCount/$_maxRetries');
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
        await _loadMessagesWithRetry(myUid, otherUserId);
      } else {
        throw Exception('Failed to load messages after $_maxRetries retries');
      }
    }
  }

  /// Real-time listener with auto-reconnect on error
  void _startListeningToMessages(String myUid, String otherUserId) {
    _messageSubscription?.cancel();

    try {
      final ref = _firebase.getChatMessagesRef(myUid, otherUserId);
      
      _messageSubscription = ref.onChildAdded.listen(
        (event) {
          try {
            if (event.snapshot.value != null) {
              final data = Map<String, dynamic>.from(event.snapshot.value as Map);
              data['id'] = event.snapshot.key;

              final newMessage = ChatMessage.fromMap(data);
              final exists = _messages.any((m) => m.id == newMessage.id);
              
              if (!exists) {
                _messages.add(newMessage);
                _messages.sort((a, b) => 
                  (a.timestamp ?? DateTime.now()).compareTo(b.timestamp ?? DateTime.now())
                );
                ErrorHandler.logSuccess('New message received from ${newMessage.senderId}');
                notifyListeners();
              }
            }
          } catch (e) {
            ErrorHandler.logError('Error processing received message', e);
          }
        },
        onError: (error) {
          ErrorHandler.logError('Chat listener error', error);
          _setError('Lost connection to chat. Reconnecting...');
          // Auto-reconnect after delay
          Future.delayed(const Duration(seconds: 2), () {
            if (!_isLoading) {
              _startListeningToMessages(myUid, otherUserId);
            }
          });
        },
      );
    } catch (e) {
      ErrorHandler.logError('Failed to start listening to messages', e);
      _setError('Chat connection failed');
    }
  }

  bool _containsContactOrAddress(String text) {
    final lowerText = text.toLowerCase();
    
    // Check if the text contains 8 or more digits (which typically indicates a phone number)
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 8) {
      return true;
    }
    
    // Check for address keywords
    final addressKeywords = [
      'street', 'house', 'gali', 'road', 'sector', 'block', 'mohalla', 'address', 'town', 
      'h#', 'st#', 'flat', 'apartment', 'home number', 'house number', 'plot #', 'plot number', 'gali number'
    ];
    for (final keyword in addressKeywords) {
      if (lowerText.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }

  /// Send message with retry logic and error handling
  Future<bool> sendMessage(String myUid, String receiverId, String text) async {
    if (text.trim().isEmpty) {
      _setError('Message cannot be empty');
      return false;
    }

    _setLoading(true);
    _clearError();

    // Prevent sharing contact details or addresses if there's no confirmed booking between the users
    if (_containsContactOrAddress(text)) {
      final hasBooking = await _firebase.hasConfirmedBooking(myUid, receiverId);
      if (!hasBooking) {
        _setError('⚠️ Phone numbers and addresses cannot be shared before a booking is confirmed!');
        _setLoading(false);
        return false;
      }
    }

    int retries = 0;

    try {
      while (retries < _maxRetries) {
        try {
          // Always send to RTDB for real-time delivery
          final success = await _firebase.sendMessage(myUid, receiverId, text);
          
          if (success) {
            // Try backend send for tracking (non-blocking)
            try {
              await _api.sendMessage(receiverId: receiverId, text: text)
                  .timeout(const Duration(seconds: 5));
              ErrorHandler.logSuccess('Message sent and tracked');
            } catch (e) {
              ErrorHandler.logWarning('Message sent but backend tracking failed: $e');
            }
            return true;
          }
          
          throw Exception('Firebase send returned false');
        } on TimeoutException {
          retries++;
          if (retries < _maxRetries) {
            ErrorHandler.logWarning('Send timeout, retry $retries/$_maxRetries');
            await Future.delayed(Duration(milliseconds: 500 * retries));
          } else {
            throw Exception('Message send timeout after $_maxRetries attempts');
          }
        }
      }
      
      _setError('Failed to send message. Please try again.');
      return false;
    } catch (e) {
      ErrorHandler.logError('sendMessage failed', e);
      _setError('Failed to send message: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Load all conversations with error handling
  Future<void> loadConversations(String myUid) async {
    _setLoading(true);
    _clearError();

    try {
      final convos = await _firebase.getConversations(myUid)
          .timeout(const Duration(seconds: 15));
      
      _conversations = convos.map((c) => ChatConversation(
        chatId: c['chatId'] ?? '',
        otherUserId: c['otherUserId'] ?? '',
        otherUserName: c['otherUserName'] ?? 'User',
        otherUserPhoto: c['otherUserPhoto'],
        lastMessage: c['lastMessage'] ?? '',
        lastUpdated: c['lastTimestamp'] ?? c['lastUpdated'] ?? 0,
      )).toList();
      
      ErrorHandler.logSuccess('Loaded ${_conversations.length} conversations');
      notifyListeners();
    } on TimeoutException {
      _setError('Failed to load conversations. Timeout.');
      ErrorHandler.logError('loadConversations timeout', 'Request exceeded 15 seconds');
    } catch (e) {
      ErrorHandler.logError('loadConversations failed', e);
      _setError('Failed to load conversations: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  void clearMessages() {
    try {
      _messageSubscription?.cancel();
      _messages = [];
      _clearError();
      notifyListeners();
    } catch (e) {
      ErrorHandler.logError('clearMessages error', e);
    }
  }

  void clearError() {
    _clearError();
  }

  void _clearError() {
    _error = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    ErrorHandler.logWarning('Chat error: $error');
    notifyListeners();
  }
  
  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
