import 'package:ziesocial/core/constants.dart';

class PostResponse {
  final List<PostModel> data;

  PostResponse({required this.data});

  factory PostResponse.fromJson(Map<String, dynamic> json) {
    return PostResponse(
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => PostModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'data': data.map((post) => post.toJson()).toList(),
      };
}

class PostModel {
  final int id;
  final String caption;
  final String image;
  final String createDate;
  final String updatedDate;
  final AuthorModel author;
  final int likeCount;
  final int commentCount;
  final bool isLiked;

  PostModel({
    required this.id,
    required this.caption,
    required this.image,
    required this.createDate,
    required this.updatedDate,
    required this.author,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
  });

  String get fullImageUrl {
    if (image.isEmpty) return '';
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    final serverRoot = ApiConstants.baseUrl.replaceAll('/api', '');
    final cleanPath = image.startsWith('/') ? image.substring(1) : image;
    return '$serverRoot/$cleanPath';
  }

  PostModel copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
  }) {
    return PostModel(
      id: id,
      caption: caption,
      image: image,
      createDate: createDate,
      updatedDate: updatedDate,
      author: author,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      caption: json['caption']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      createDate: json['create_date']?.toString() ?? '',
      updatedDate: json['updated_date']?.toString() ?? '',
      author: AuthorModel.fromJson(
        json['author'] is Map<String, dynamic>
            ? json['author'] as Map<String, dynamic>
            : {},
      ),
      likeCount: json['like_count'] is int
          ? json['like_count']
          : int.tryParse(json['like_count']?.toString() ?? '0') ?? 0,
      commentCount: json['comment_count'] is int
          ? json['comment_count']
          : int.tryParse(json['comment_count']?.toString() ?? '0') ?? 0,
      isLiked: json['is_liked'] == true || json['is_liked'] == 1 || json['is_liked'] == '1',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'caption': caption,
        'image': image,
        'create_date': createDate,
        'updated_date': updatedDate,
        'author': author.toJson(),
        'like_count': likeCount,
        'comment_count': commentCount,
        'is_liked': isLiked,
      };
}

class AuthorModel {
  final int id;
  final String username;
  final String name;
  final String avatar;

  AuthorModel({
    required this.id,
    required this.username,
    required this.name,
    required this.avatar,
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

  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    return AuthorModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'avatar': avatar,
      };
}

class CommentModel {
  final int id;
  final int userId;
  final int postId;
  final String text;
  final String createDate;
  final AuthorModel author;

  CommentModel({
    required this.id,
    required this.userId,
    required this.postId,
    required this.text,
    required this.createDate,
    required this.author,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      postId: json['post_id'] is int ? json['post_id'] : int.tryParse(json['post_id']?.toString() ?? '0') ?? 0,
      text: json['text']?.toString() ?? '',
      createDate: json['create_date']?.toString() ?? '',
      author: AuthorModel.fromJson(
        json['author'] is Map<String, dynamic>
            ? json['author'] as Map<String, dynamic>
            : {
                'id': json['user_id'],
                'username': json['username'] ?? '',
                'name': json['name'] ?? '',
                'avatar': json['avatar'] ?? '',
              },
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'post_id': postId,
        'text': text,
        'create_date': createDate,
        'author': author.toJson(),
      };
}
