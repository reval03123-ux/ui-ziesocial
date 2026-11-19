import 'package:flutter/foundation.dart';

class ApiConstants {
  // ── 1. URL Ngrok (Untuk akses HP dari internet/Wi-Fi) ──
  static const String ngrokHost = 'https://trickle-curling-conceal.ngrok-free.dev';

  // ── 2. URL Localhost (Untuk akses langsung di Chrome / Laptop) ──
  static const String localHost = 'http://localhost';

  // ── 3. (Alternatif) IP Wi-Fi Laptop jika HP & Laptop di 1 Wi-Fi tanpa Ngrok ──
  // static const String wifiHost = 'http://10.174.176.50';

  static String get baseUrl {
    if (kIsWeb) {
      // Di Chrome laptop: langsung ke localhost XAMPP (cepat, stabil, bebas limit ngrok)
      return '$localHost/ziesocial/api';
    }
    // Di HP (Android/iOS): gunakan URL Ngrok agar bisa terhubung ke server laptop
    return '$ngrokHost/ziesocial/api';
  }

  static String get serverUrl => baseUrl.replaceAll('/api', '');

  static String get login => '$baseUrl/auth/login.php';
  static String get register => '$baseUrl/auth/register.php';
  static String get createPost => '$baseUrl/posts/create.php';
  static String get getPosts => '$baseUrl/posts/read.php';
  static String get deletePost => '$baseUrl/posts/delete.php';
  static String get toggleLike => '$baseUrl/likes/toggle.php';
  static String get getComments => '$baseUrl/comments/read.php';
  static String get addComment => '$baseUrl/comments/create.php';
  static String get deleteComment => '$baseUrl/comments/delete.php';
  static String get editComment => '$baseUrl/comments/update.php';
  static String get updateAvatar => '$baseUrl/users/update_avatar.php';
  static String get updateProfile => '$baseUrl/users/update_profile.php';
  static String get toggleFollow => '$baseUrl/follows/toggle.php';
  static String get getFollows => '$baseUrl/follows/read.php';
  static String get profile => '$baseUrl/users/profile.php';
  static String get searchUsers => '$baseUrl/users/search.php';
  static String get createStory => '$baseUrl/stories/create.php';
  static String get getStories => '$baseUrl/stories/read.php';
  static String get deleteStory => '$baseUrl/stories/delete.php';
  static String get getConversations => '$baseUrl/messages/conversations.php';
  static String get getMessages => '$baseUrl/messages/read.php';
  static String get sendMessage => '$baseUrl/messages/send.php';
  static String get typing => '$baseUrl/messages/typing.php';
  static String get deleteMessage => '$baseUrl/messages/delete.php';
  static String get deleteConversation => '$baseUrl/messages/delete_conversation.php';
  static String get reactMessage => '$baseUrl/messages/reaction.php';
  static String get heartbeat => '$baseUrl/users/heartbeat.php';
  static String get getNotifications => '$baseUrl/notifications/read.php';
  static String get markNotificationsRead => '$baseUrl/notifications/mark_read.php';
  static String get getUnreadCounts => '$baseUrl/notifications/unread_count.php';
  static String get saveFcmToken => '$baseUrl/users/save_fcm_token.php';
}
