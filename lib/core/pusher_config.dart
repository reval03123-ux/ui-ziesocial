class PusherConfig {
  // Masukkan kredensial Pusher Anda dari https://dashboard.pusher.com
  static const String appId = "YOUR_PUSHER_APP_ID";
  static const String apiKey = "YOUR_PUSHER_KEY";
  static const String cluster = "ap1"; // Contoh: ap1, us2, eu, dll.

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      apiKey != "YOUR_PUSHER_KEY" &&
      appId != "YOUR_PUSHER_APP_ID";

  /// Format nama channel 1-on-1: chat-{min_id}-{max_id}
  static String getChatChannel(int userId1, int userId2) {
    final minId = userId1 < userId2 ? userId1 : userId2;
    final maxId = userId1 > userId2 ? userId1 : userId2;
    return 'chat-$minId-$maxId';
  }

  /// Format channel per user: user-{user_id} (untuk notifikasi obrolan/unread)
  static String getUserChannel(int userId) {
    return 'user-$userId';
  }

  static const String eventNewMessage = 'new-message';
}
