import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/model/post_model.dart';
import 'package:ziesocial/model/user_model.dart';

class ProfileStats {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;

  ProfileStats({
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
  });

  ProfileStats copyWith({
    int? postsCount,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
  }) {
    return ProfileStats(
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      postsCount: json['posts_count'] is int
          ? json['posts_count']
          : int.tryParse(json['posts_count']?.toString() ?? '0') ?? 0,
      followersCount: json['followers_count'] is int
          ? json['followers_count']
          : int.tryParse(json['followers_count']?.toString() ?? '0') ?? 0,
      followingCount: json['following_count'] is int
          ? json['following_count']
          : int.tryParse(json['following_count']?.toString() ?? '0') ?? 0,
      isFollowing: json['is_following'] == true ||
          json['is_following'] == 1 ||
          json['is_following'] == '1',
    );
  }
}

class ProfileModel {
  final UserModel user;
  final ProfileStats stats;
  final List<PostModel> posts;

  ProfileModel({
    required this.user,
    required this.stats,
    required this.posts,
  });

  ProfileModel copyWith({
    UserModel? user,
    ProfileStats? stats,
    List<PostModel>? posts,
  }) {
    return ProfileModel(
      user: user ?? this.user,
      stats: stats ?? this.stats,
      posts: posts ?? this.posts,
    );
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] as Map<String, dynamic>? ?? {};
    final statsData = json['stats'] as Map<String, dynamic>? ?? {};
    final postsData = json['posts'] as List<dynamic>? ?? [];

    return ProfileModel(
      user: UserModel.fromJson(userData),
      stats: ProfileStats.fromJson(statsData),
      posts: postsData
          .map((item) => PostModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SearchUserModel {
  final int id;
  final String username;
  final String name;
  final String avatar;
  final String bio;
  final int followersCount;
  final bool isFollowing;

  SearchUserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.avatar,
    required this.bio,
    required this.followersCount,
    required this.isFollowing,
  });

  String get avatarUrl {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }
    final serverRoot = ApiConstants.baseUrl.replaceAll('/api', '');
    final cleanPath = avatar.startsWith('/') ? avatar.substring(1) : avatar;
    return '$serverRoot/$cleanPath';
  }

  SearchUserModel copyWith({
    bool? isFollowing,
    int? followersCount,
  }) {
    return SearchUserModel(
      id: id,
      username: username,
      name: name,
      avatar: avatar,
      bio: bio,
      followersCount: followersCount ?? this.followersCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  factory SearchUserModel.fromJson(Map<String, dynamic> json) {
    return SearchUserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      followersCount: json['followers_count'] is int
          ? json['followers_count']
          : int.tryParse(json['followers_count']?.toString() ?? '0') ?? 0,
      isFollowing: json['is_following'] == true ||
          json['is_following'] == 1 ||
          json['is_following'] == '1',
    );
  }
}
