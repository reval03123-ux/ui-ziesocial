import 'package:ziesocial/core/constants.dart';

class UserModel {
  final String id;
  final String username;
  final String email;
  final String name;
  final String avatar;
  final String bio;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.avatar,
    required this.bio,
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

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
    String? avatar,
    String? bio,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      bio: json['bio'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'name': name,
        'avatar': avatar,
        'bio': bio,
      };
}
