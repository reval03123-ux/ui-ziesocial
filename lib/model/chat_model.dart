import 'package:ziesocial/core/constants.dart';

class ChatPeer {
  final int id;
  final String username;
  final String name;
  final String avatar;
  final bool isOnline;
  final String lastActive;

  ChatPeer({
    required this.id,
    required this.username,
    required this.name,
    required this.avatar,
    this.isOnline = false,
    this.lastActive = '',
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
      isOnline: json['is_online'] == true ||
          json['is_online'] == 1 ||
          json['is_online'] == '1' ||
          json['is_online'] == 'true',
      lastActive: json['last_active']?.toString() ?? '',
    );
  }

  ChatPeer copyWith({
    bool? isOnline,
    String? lastActive,
  }) {
    return ChatPeer(
      id: id,
      username: username,
      name: name,
      avatar: avatar,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}

class ChatReaction {
  final int id;
  final int userId;
  final String username;
  final String name;
  final String emoji;

  ChatReaction({
    required this.id,
    required this.userId,
    required this.username,
    required this.name,
    required this.emoji,
  });

  factory ChatReaction.fromJson(Map<String, dynamic> json) {
    return ChatReaction(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '',
    );
  }
}

class ChatReply {
  final int id;
  final int senderId;
  final String senderName;
  final String senderUsername;
  final String message;
  final String? image;

  ChatReply({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderUsername,
    required this.message,
    this.image,
  });

  String? get imageUrl {
    if (image == null || image!.isEmpty) return null;
    if (image!.startsWith('http')) return image;
    return '${ApiConstants.serverUrl}/$image';
  }

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    return ChatReply(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      senderId: json['sender_id'] is int
          ? json['sender_id']
          : int.tryParse(json['sender_id']?.toString() ?? '0') ?? 0,
      senderName: json['sender_name']?.toString() ?? '',
      senderUsername: json['sender_username']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      image: json['image']?.toString(),
    );
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String message;
  final String? image;
  final ChatReply? replyTo;
  final List<ChatReaction> reactions;
  final bool isMine;
  final bool isRead;
  final String createDate;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.image,
    this.replyTo,
    this.reactions = const [],
    required this.isMine,
    required this.isRead,
    required this.createDate,
  });

  String? get imageUrl {
    if (image == null || image!.isEmpty) return null;
    if (image!.startsWith('http')) return image;
    return '${ApiConstants.serverUrl}/$image';
  }

  /// Menghitung frekuensi kemunculan tiap emoji pada pesan ini
  Map<String, int> get reactionCounts {
    final Map<String, int> counts = {};
    for (final r in reactions) {
      if (r.emoji.isNotEmpty) {
        counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Mengetahui apakah current user sudah memberikan reaction
  String? myReaction(int currentUserId) {
    for (final r in reactions) {
      if (r.userId == currentUserId) return r.emoji;
    }
    return null;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    ChatReply? reply;
    if (json['reply_to'] is Map<String, dynamic>) {
      reply = ChatReply.fromJson(json['reply_to'] as Map<String, dynamic>);
    } else if (json['reply_to'] is Map) {
      reply = ChatReply.fromJson(Map<String, dynamic>.from(json['reply_to'] as Map));
    }

    final List<ChatReaction> reactsList = [];
    if (json['reactions'] is List) {
      for (final item in json['reactions'] as List) {
        if (item is Map) {
          reactsList.add(ChatReaction.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

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
      image: json['image']?.toString(),
      replyTo: reply,
      reactions: reactsList,
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

  ChatMessage copyWith({
    bool? isRead,
    List<ChatReaction>? reactions,
    ChatReply? replyTo,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      image: image,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
      isMine: isMine,
      isRead: isRead ?? this.isRead,
      createDate: createDate,
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
