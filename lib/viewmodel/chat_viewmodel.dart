import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/model/chat_model.dart';

class ChatViewModel extends ChangeNotifier {
  final ApiClient _apiClient;

  ChatViewModel(this._apiClient);

  List<ChatConversation> _conversations = [];
  List<ChatMessage> _currentMessages = [];
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _errorMessage;
  int _totalUnreadCount = 0;

  Timer? _pollTimer;
  int? _activeUserId;
  int? _activePeerId;

  List<ChatConversation> get conversations => _conversations;
  List<ChatMessage> get currentMessages => _currentMessages;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  int get totalUnreadCount => _totalUnreadCount;

  Future<void> fetchConversations(int userId) async {
    _isLoadingConversations = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '${ApiConstants.getConversations}?user_id=$userId',
      );
      final rawList = response['data'] as List<dynamic>? ?? [];
      _conversations = rawList
          .map((item) => ChatConversation.fromJson(item as Map<String, dynamic>))
          .toList();

      _totalUnreadCount = _conversations.fold<int>(
        0,
        (sum, item) => sum + item.unreadCount,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> fetchMessages({
    required int userId,
    required int peerId,
    bool isInitial = true,
  }) async {
    if (isInitial) {
      _isLoadingMessages = true;
      _currentMessages = [];
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await _apiClient.get(
        '${ApiConstants.getMessages}?user_id=$userId&peer_id=$peerId',
      );
      final rawList = response['data'] as List<dynamic>? ?? [];
      _currentMessages = rawList
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();

      // Reset unread count for this peer in conversation list
      final index = _conversations.indexWhere((c) => c.peer.id == peerId);
      if (index != -1) {
        final conv = _conversations[index];
        _conversations[index] = ChatConversation(
          peer: conv.peer,
          lastMessage: conv.lastMessage,
          unreadCount: 0,
        );
        _totalUnreadCount = _conversations.fold<int>(
          0,
          (sum, item) => sum + item.unreadCount,
        );
      }
    } catch (e) {
      if (isInitial) {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (isInitial) {
        _isLoadingMessages = false;
      }
      notifyListeners();
    }
  }

  Future<void> _pollNewMessages() async {
    if (_activeUserId == null || _activePeerId == null) return;

    final lastId =
        _currentMessages.isNotEmpty ? _currentMessages.last.id : 0;

    try {
      final url =
          '${ApiConstants.getMessages}?user_id=$_activeUserId&peer_id=$_activePeerId&after_id=$lastId';
      final response = await _apiClient.get(url);
      final rawList = response['data'] as List<dynamic>? ?? [];

      if (rawList.isNotEmpty) {
        final newMsgs = rawList
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();

        // Hindari duplikasi
        for (final msg in newMsgs) {
          if (!_currentMessages.any((m) => m.id == msg.id)) {
            _currentMessages.add(msg);
          }
        }
        notifyListeners();
      }
    } catch (_) {
      // Polling error silently handled to prevent UI disruption
    }
  }

  void startPolling({required int userId, required int peerId}) {
    stopPolling();
    _activeUserId = userId;
    _activePeerId = peerId;

    _pollTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      _pollNewMessages();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _activeUserId = null;
    _activePeerId = null;
  }

  Future<bool> sendMessage({
    required int senderId,
    required int receiverId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return false;

    _isSending = true;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        ApiConstants.sendMessage,
        body: {
          'sender_id': senderId,
          'receiver_id': receiverId,
          'message': text.trim(),
        },
      );

      if (response['status'] == true && response['data'] != null) {
        final newMsg =
            ChatMessage.fromJson(response['data'] as Map<String, dynamic>);
        if (!_currentMessages.any((m) => m.id == newMsg.id)) {
          _currentMessages.add(newMsg);
        }
        // Perbarui conversation list jika ada
        final index = _conversations.indexWhere((c) => c.peer.id == receiverId);
        if (index != -1) {
          final conv = _conversations[index];
          _conversations[index] = ChatConversation(
            peer: conv.peer,
            lastMessage: newMsg,
            unreadCount: 0,
          );
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

