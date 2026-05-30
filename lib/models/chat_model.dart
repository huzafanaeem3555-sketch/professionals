class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] is int ? map['timestamp'] : (map['timestamp'] as double).toInt())
          : null,
      isRead: map['isRead'] ?? false,
    );
  }
}

class ChatConversation {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String lastMessage;
  final int lastUpdated;

  ChatConversation({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.lastMessage,
    required this.lastUpdated,
  });

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    return ChatConversation(
      chatId: map['chatId'] ?? '',
      otherUserId: map['otherUserId'] ?? '',
      otherUserName: map['otherUserName'] ?? 'User',
      otherUserPhoto: map['otherUserPhoto'],
      lastMessage: map['lastMessage'] ?? '',
      lastUpdated: map['lastUpdated'] ?? 0,
    );
  }
}
