import 'package:ziesocial/core/constants.dart';

class ChatPeer {
  final int id;
  final String username;
  final String name;
  final String avatar;

  ChatPeer({
    required this.id,
    required this.username,
    required this.name,
    required this.avatar,
  });

  String get avatarUrl {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return '${ApiConstants.serverUrl}/$avatar';
  }

  factory ChatPeer.fromJson(Map<String, dynamic> json) {
    return ChatPeer(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
    );
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String message;
  final bool isMine;
  final bool isRead;
  final String createDate;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.isMine,
    required this.isRead,
    required this.createDate,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      senderId: json['sender_id'] is int
          ? json['sender_id']
          : int.tryParse(json['sender_id']?.toString() ?? '0') ?? 0,
      receiverId: json['receiver_id'] is int
          ? json['receiver_id']
          : int.tryParse(json['receiver_id']?.toString() ?? '0') ?? 0,
      message: json['message']?.toString() ?? '',
      isMine: json['is_mine'] == true ||
          json['is_mine'] == 1 ||
          json['is_mine'] == '1' ||
          json['is_mine'] == 'true',
      isRead: json['is_read'] == true ||
          json['is_read'] == 1 ||
          json['is_read'] == '1' ||
          json['is_read'] == 'true',
      createDate: json['create_date']?.toString() ?? '',
    );
  }
}

class ChatConversation {
  final ChatPeer peer;
  final ChatMessage lastMessage;
  final int unreadCount;

  ChatConversation({
    required this.peer,
    required this.lastMessage,
    required this.unreadCount,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      peer: ChatPeer.fromJson(json['peer'] as Map<String, dynamic>? ?? {}),
      lastMessage: ChatMessage.fromJson(
          json['last_message'] as Map<String, dynamic>? ?? {}),
      unreadCount: json['unread_count'] is int
          ? json['unread_count']
          : int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
    );
  }
}

