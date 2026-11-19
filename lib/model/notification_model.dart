import 'package:ziesocial/core/constants.dart';

class NotificationSender {
  final int id;
  final String username;
  final String name;
  final String avatar;
  bool isFollowing;

  NotificationSender({
    required this.id,
    required this.username,
    required this.name,
    required this.avatar,
    this.isFollowing = false,
  });

  String get avatarUrl {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }
    final clean = avatar.startsWith('/') ? avatar.substring(1) : avatar;
    return '${ApiConstants.serverUrl}/$clean';
  }

  factory NotificationSender.fromJson(Map<String, dynamic> json) {
    return NotificationSender(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      isFollowing: json['is_following'] == true || json['is_following'] == 1 || json['is_following'] == '1',
    );
  }
}

class NotificationItem {
  final int id;
  final int userId;
  final int senderId;
  final String type; // 'like', 'comment', 'follow', 'chat'
  final int? postId;
  final int? commentId;
  final String message;
  final String? postImage;
  bool isRead;
  final String createDate;
  final NotificationSender sender;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.senderId,
    required this.type,
    this.postId,
    this.commentId,
    required this.message,
    this.postImage,
    required this.isRead,
    required this.createDate,
    required this.sender,
  });

  String? get postImageUrl {
    if (postImage == null || postImage!.isEmpty) return null;
    if (postImage!.startsWith('http://') || postImage!.startsWith('https://')) {
      return postImage;
    }
    final clean = postImage!.startsWith('/') ? postImage!.substring(1) : postImage!;
    return '${ApiConstants.serverUrl}/$clean';
  }

  String get formattedTime {
    try {
      final dt = DateTime.parse(createDate.replaceAll(' ', 'T'));
      final diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}j';
      if (diff.inDays < 7) return '${diff.inDays}h';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}mg';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> senderMap = {};
    if (json['sender'] is Map) {
      senderMap = Map<String, dynamic>.from(json['sender'] as Map);
    } else {
      senderMap = {
        'id': json['sender_id'],
        'username': json['sender_username'] ?? '',
        'name': json['sender_name'] ?? '',
        'avatar': json['sender_avatar'] ?? '',
        'is_following': json['is_following'] ?? false,
      };
    }

    return NotificationItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      senderId: json['sender_id'] is int ? json['sender_id'] : int.tryParse(json['sender_id']?.toString() ?? '') ?? 0,
      type: json['type']?.toString() ?? 'general',
      postId: json['post_id'] != null ? int.tryParse(json['post_id'].toString()) : null,
      commentId: json['comment_id'] != null ? int.tryParse(json['comment_id'].toString()) : null,
      message: json['message']?.toString() ?? '',
      postImage: json['post_image']?.toString(),
      isRead: json['is_read'] == true || json['is_read'] == 1 || json['is_read'] == '1',
      createDate: json['create_date']?.toString() ?? '',
      sender: NotificationSender.fromJson(senderMap),
    );
  }
}
