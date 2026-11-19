import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/notification_model.dart';
import 'package:ziesocial/service/pusher_service.dart';

enum AlertType { like, comment, follow, chat }

class InAppAlert {
  final AlertType type;
  final String title;
  final String subtitle;
  final String avatarUrl;
  final String? postImageUrl;
  final Map<String, dynamic> rawData;

  InAppAlert({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    this.postImageUrl,
    required this.rawData,
  });
}

class NotificationViewModel extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final PusherChatService _pusherService = PusherChatService();

  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  int _unreadMessagesCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _pollingTimer;
  int? _subscribedUserId;

  InAppAlert? _latestAlert;
  Timer? _alertDismissTimer;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  int get unreadMessagesCount => _unreadMessagesCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  InAppAlert? get latestAlert => _latestAlert;

  /// Inisialisasi ViewModel dengan User ID yang sedang login
  void init(int userId) {
    if (userId <= 0) return;
    if (_subscribedUserId == userId) return;

    _subscribedUserId = userId;

    // 1. Ambil data awal
    fetchNotifications(userId);
    fetchUnreadCounts(userId);

    // 2. Hubungkan Pusher ke channel pengguna pribadi
    _setupPusher(userId);

    // 3. Polling fallback setiap 20 detik untuk sinkronisasi cadangan
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_subscribedUserId != null) {
        fetchUnreadCounts(_subscribedUserId!);
      }
    });
  }

  Future<void> _setupPusher(int userId) async {
    await _pusherService.initPusher(
      onNewNotification: (data) => _handleIncomingNotification(data),
      onUserIncomingMessage: (data) => _handleIncomingChatMessage(data),
    );

    // Callback listeners
    _pusherService.setNotificationCallback((data) => _handleIncomingNotification(data));
    _pusherService.setUserIncomingMessageCallback((data) => _handleIncomingChatMessage(data));

    await _pusherService.subscribeToUserChannel(userId);
  }

  /// Memuat daftar notifikasi dari server
  Future<void> fetchNotifications(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiClient.get('${ApiConstants.getNotifications}?user_id=$userId');
      if (res['status'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .map((item) => NotificationItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _notifications = list;
        _unreadCount = res['unread_count'] is int ? res['unread_count'] : 0;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Memperbarui badge notifikasi & pesan yang belum dibaca
  Future<void> fetchUnreadCounts(int userId) async {
    try {
      final res = await _apiClient.get('${ApiConstants.getUnreadCounts}?user_id=$userId');
      if (res['status'] == true) {
        _unreadCount = res['unread_notifications'] is int ? res['unread_notifications'] : 0;
        _unreadMessagesCount = res['unread_messages'] is int ? res['unread_messages'] : 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Menandai semua notifikasi telah dibaca
  Future<void> markAllAsRead(int userId) async {
    _unreadCount = 0;
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();

    try {
      await _apiClient.post(
        ApiConstants.markNotificationsRead,
        body: {'user_id': userId},
      );
    } catch (_) {}
  }

  /// Menangani event notifikasi baru secara real-time dari Pusher
  void _handleIncomingNotification(dynamic data) {
    if (data == null) return;
    try {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;

      final notif = NotificationItem.fromJson(map);

      // Cek apakah item sudah ada di daftar
      final exists = _notifications.any((n) => n.id == notif.id);
      if (!exists) {
        _notifications.insert(0, notif);
      }

      if (map['unread_count'] is int) {
        _unreadCount = map['unread_count'];
      } else {
        _unreadCount++;
      }

      // Tampilkan banner notifikasi in-app
      AlertType alertType;
      switch (notif.type) {
        case 'like':
          alertType = AlertType.like;
          break;
        case 'comment':
          alertType = AlertType.comment;
          break;
        case 'follow':
          alertType = AlertType.follow;
          break;
        default:
          alertType = AlertType.like;
      }

      _showAlert(InAppAlert(
        type: alertType,
        title: notif.sender.name.isNotEmpty ? notif.sender.name : notif.sender.username,
        subtitle: notif.message,
        avatarUrl: notif.sender.avatarUrl,
        postImageUrl: notif.postImageUrl,
        rawData: map,
      ));

      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationVM] Error parsing incoming notification: $e');
    }
  }

  /// Menangani event chat baru secara real-time dari Pusher
  void _handleIncomingChatMessage(dynamic data) {
    if (data == null) return;
    try {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;

      _unreadMessagesCount++;

      final senderName = map['sender_name']?.toString() ?? 'Pesan Baru';
      final username = map['sender_username']?.toString() ?? '';
      final avatar = map['sender_avatar']?.toString() ?? '';
      final msg = map['message']?.toString() ?? '';
      final img = map['image']?.toString();

      String subtitle = msg.isNotEmpty ? msg : (img != null ? '📷 Mengirim foto' : 'Mengirim pesan');

      String avatarUrl = '';
      if (avatar.isNotEmpty) {
        if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
          avatarUrl = avatar;
        } else {
          final clean = avatar.startsWith('/') ? avatar.substring(1) : avatar;
          avatarUrl = '${ApiConstants.serverUrl}/$clean';
        }
      }

      _showAlert(InAppAlert(
        type: AlertType.chat,
        title: senderName.isNotEmpty ? senderName : username,
        subtitle: subtitle,
        avatarUrl: avatarUrl,
        rawData: map,
      ));

      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationVM] Error parsing incoming chat: $e');
    }
  }

  void _showAlert(InAppAlert alert) {
    _latestAlert = alert;
    _alertDismissTimer?.cancel();
    _alertDismissTimer = Timer(const Duration(seconds: 4), () {
      _latestAlert = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void dismissAlert() {
    _alertDismissTimer?.cancel();
    _latestAlert = null;
    notifyListeners();
  }

  /// Toggle Follow dari baris notifikasi
  Future<void> toggleFollowUser({
    required int currentUserId,
    required int targetUserId,
    required NotificationItem item,
  }) async {
    final prevStatus = item.sender.isFollowing;
    item.sender.isFollowing = !prevStatus;
    notifyListeners();

    try {
      await _apiClient.post(
        ApiConstants.toggleFollow,
        body: {
          'follower_id': currentUserId,
          'following_id': targetUserId,
        },
      );
    } catch (_) {
      // Revert if error
      item.sender.isFollowing = prevStatus;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _alertDismissTimer?.cancel();
    super.dispose();
  }
}
