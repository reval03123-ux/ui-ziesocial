import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:ziesocial/core/pusher_config.dart';

typedef PusherService = PusherChatService;

class PusherChatService {
  static final PusherChatService _instance = PusherChatService._internal();
  factory PusherChatService() => _instance;
  PusherChatService._internal();

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  bool _isInitialized = false;
  String? _currentChatChannel;
  String? _currentUserChannel;

  Function(dynamic messageData)? _onMessageCallback;
  Function(dynamic readData)? _onReadCallback;
  Function(dynamic notifData)? _onNotificationCallback;
  Function(dynamic messageData)? _onUserIncomingMessageCallback;
  Function(dynamic typingData)? _onTypingCallback;
  Function(dynamic deleteData)? _onMessageDeletedCallback;
  Function(dynamic convData)? _onConversationDeletedCallback;
  Function(dynamic reactionData)? _onMessageReactionCallback;

  /// Inisialisasi koneksi Pusher
  Future<void> initPusher({
    Function(dynamic messageData)? onNewMessage,
    Function(dynamic readData)? onMessagesRead,
    Function(dynamic notifData)? onNewNotification,
    Function(dynamic messageData)? onUserIncomingMessage,
  }) async {
    if (onNewMessage != null) _onMessageCallback = onNewMessage;
    if (onMessagesRead != null) _onReadCallback = onMessagesRead;
    if (onNewNotification != null) _onNotificationCallback = onNewNotification;
    if (onUserIncomingMessage != null) {
      _onUserIncomingMessageCallback = onUserIncomingMessage;
    }

    if (!PusherConfig.isConfigured) {
      debugPrint('[Pusher] Kredensial Pusher belum diisi pada lib/core/pusher_config.dart');
      return;
    }

    if (_isInitialized) return;

    try {
      await _pusher.init(
        apiKey: PusherConfig.apiKey,
        cluster: PusherConfig.cluster,
        onEvent: (PusherEvent event) {
          debugPrint('[Pusher] Event: ${event.eventName} di ${event.channelName}');
          dynamic data = event.data;
          if (data is String) {
            try {
              data = jsonDecode(data);
            } catch (_) {}
          }

          if (event.eventName == PusherConfig.eventNewMessage && data != null) {
            // Callback untuk room chat yang sedang aktif
            _onMessageCallback?.call(data);

            // Callback untuk notifikasi banner / unread chat di level user
            if (event.channelName == _currentUserChannel) {
              _onUserIncomingMessageCallback?.call(data);
            }
          } else if (event.eventName == PusherConfig.eventMessagesRead && data != null) {
            _onReadCallback?.call(data);
          } else if (event.eventName == PusherConfig.eventNewNotification && data != null) {
            _onNotificationCallback?.call(data);
          } else if (event.eventName == PusherConfig.eventTyping && data != null) {
            _onTypingCallback?.call(data);
          } else if (event.eventName == PusherConfig.eventMessageDeleted && data != null) {
            _onMessageDeletedCallback?.call(data);
          } else if (event.eventName == PusherConfig.eventConversationDeleted && data != null) {
            _onConversationDeletedCallback?.call(data);
          } else if (event.eventName == PusherConfig.eventMessageReaction && data != null) {
            _onMessageReactionCallback?.call(data);
          }
        },
        onError: (String message, int? code, dynamic error) {
          debugPrint('[Pusher] Error ($code): $message');
        },
        onConnectionStateChange: (currentState, previousState) {
          debugPrint('[Pusher] Status koneksi: $previousState -> $currentState');
        },
      );

      await _pusher.connect();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[Pusher] Inisialisasi gagal: $e');
    }
  }

  void setNotificationCallback(Function(dynamic notifData)? callback) {
    _onNotificationCallback = callback;
  }

  void setUserIncomingMessageCallback(Function(dynamic messageData)? callback) {
    _onUserIncomingMessageCallback = callback;
  }

  void setMessageCallback(Function(dynamic messageData)? callback) {
    _onMessageCallback = callback;
  }

  void setReadCallback(Function(dynamic readData)? callback) {
    _onReadCallback = callback;
  }

  void setTypingCallback(Function(dynamic typingData)? callback) {
    _onTypingCallback = callback;
  }

  void setMessageDeletedCallback(Function(dynamic deleteData)? callback) {
    _onMessageDeletedCallback = callback;
  }

  void setConversationDeletedCallback(Function(dynamic convData)? callback) {
    _onConversationDeletedCallback = callback;
  }

  void setMessageReactionCallback(Function(dynamic reactionData)? callback) {
    _onMessageReactionCallback = callback;
  }

  /// Subscribe ke channel user: user-{userId} (untuk notifikasi aktivitas & pesan masuk)
  Future<void> subscribeToUserChannel(int userId) async {
    if (!PusherConfig.isConfigured || userId <= 0) return;

    final channelName = PusherConfig.getUserChannel(userId);
    if (_currentUserChannel == channelName) return;

    try {
      if (_currentUserChannel != null) {
        await _pusher.unsubscribe(channelName: _currentUserChannel!);
      }
      _currentUserChannel = channelName;
      await _pusher.subscribe(channelName: channelName);
      debugPrint('[Pusher] Subscribed ke user channel: $channelName');
    } catch (e) {
      debugPrint('[Pusher] Gagal subscribe ke user channel $channelName: $e');
    }
  }

  /// Subscribe ke channel room chat 1-on-1: chat-{min}-{max}
  Future<void> subscribeToChat({
    required int userId,
    required int peerId,
  }) async {
    if (!PusherConfig.isConfigured) return;

    final channelName = PusherConfig.getChatChannel(userId, peerId);
    if (_currentChatChannel == channelName) return;

    if (_currentChatChannel != null) {
      await unsubscribeFromCurrent();
    }

    try {
      _currentChatChannel = channelName;
      await _pusher.subscribe(channelName: channelName);
      debugPrint('[Pusher] Subscribed ke chat: $channelName');
    } catch (e) {
      debugPrint('[Pusher] Gagal subscribe ke chat $channelName: $e');
    }
  }

  Future<void> unsubscribeFromCurrent() async {
    if (_currentChatChannel == null || !PusherConfig.isConfigured) return;

    try {
      final ch = _currentChatChannel!;
      _currentChatChannel = null;
      await _pusher.unsubscribe(channelName: ch);
      debugPrint('[Pusher] Unsubscribed dari chat: $ch');
    } catch (e) {
      debugPrint('[Pusher] Gagal unsubscribe dari chat: $e');
    }
  }

  Future<void> disconnect() async {
    await unsubscribeFromCurrent();
    if (_currentUserChannel != null && PusherConfig.isConfigured) {
      try {
        await _pusher.unsubscribe(channelName: _currentUserChannel!);
        _currentUserChannel = null;
      } catch (_) {}
    }
  }
}
