import 'package:ziesocial/core/constants.dart';

class StoryItem {
  final int id;
  final int userId;
  final String image;
  final String caption;
  final String createDate;

  StoryItem({
    required this.id,
    required this.userId,
    required this.image,
    required this.caption,
    required this.createDate,
  });

  String get imageUrl {
    if (image.isEmpty) return '';
    if (image.startsWith('http')) return image;
    return '${ApiConstants.serverUrl}/$image';
  }

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      image: json['image']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      createDate: json['create_date']?.toString() ?? '',
    );
  }
}

class UserStory {
  final int userId;
  final String username;
  final String name;
  final String avatar;
  final bool isCurrentUser;
  final List<StoryItem> stories;

  UserStory({
    required this.userId,
    required this.username,
    required this.name,
    required this.avatar,
    required this.isCurrentUser,
    required this.stories,
  });

  String get avatarUrl {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return '${ApiConstants.serverUrl}/$avatar';
  }

  factory UserStory.fromJson(Map<String, dynamic> json) {
    final storiesList = (json['stories'] as List<dynamic>?)
            ?.map((e) => StoryItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return UserStory(
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      isCurrentUser: json['is_current_user'] == true,
      stories: storiesList,
    );
  }
}

