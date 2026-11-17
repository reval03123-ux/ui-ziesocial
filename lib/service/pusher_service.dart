import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:ziesocial/core/pusher_config.dart';

class PusherChatService {
  static final PusherChatService _instance = PusherChatService._internal();
  factory PusherChatService() => _instance;
  PusherChatService._internal();

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  bool _isInitialized = false;
  String? _currentChannel;
  Function(dynamic messageData)? _onMessageCallback;

  Future<void> initPusher({
    required Function(dynamic messageData) onNewMessage,
  }) async {
    _onMessageCallback = onNewMessage;

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
          debugPrint('[Pusher] Event diterima: ${event.eventName} di ${event.channelName}');
          if (event.eventName == PusherConfig.eventNewMessage && event.data != null) {
            dynamic data = event.data;
            if (data is String) {
              try {
                data = jsonDecode(data);
              } catch (_) {}
            }
            if (_onMessageCallback != null) {
              _onMessageCallback!(data);
            }
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

  Future<void> subscribeToChat({
    required int userId,
    required int peerId,
  }) async {
    if (!PusherConfig.isConfigured) return;

    final channelName = PusherConfig.getChatChannel(userId, peerId);
    if (_currentChannel == channelName) return;

    if (_currentChannel != null) {
      await unsubscribeFromCurrent();
    }

    try {
      _currentChannel = channelName;
      await _pusher.subscribe(channelName: channelName);
      debugPrint('[Pusher] Berhasil subscribe ke: $channelName');
    } catch (e) {
      debugPrint('[Pusher] Gagal subscribe ke $channelName: $e');
    }
  }

  Future<void> unsubscribeFromCurrent() async {
    if (_currentChannel == null || !PusherConfig.isConfigured) return;

    try {
      final ch = _currentChannel!;
      _currentChannel = null;
      await _pusher.unsubscribe(channelName: ch);
      debugPrint('[Pusher] Unsubscribed dari: $ch');
    } catch (e) {
      debugPrint('[Pusher] Gagal unsubscribe: $e');
    }
  }

  Future<void> disconnect() async {
    await unsubscribeFromCurrent();
  }
}
