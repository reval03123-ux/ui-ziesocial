import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ziesocial/core/constants.dart';
import 'package:ziesocial/core/network.dart';
import 'package:ziesocial/core/pusher_config.dart';
import 'package:ziesocial/model/chat_model.dart';
import 'package:ziesocial/service/pusher_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ApiClient _apiClient;
  final PusherChatService _pusherService = PusherChatService();

  ChatViewModel(this._apiClient);

  List<ChatConversation> _conversations = [];
  List<ChatMessage> _currentMessages = [];
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _errorMessage;
  int _totalUnreadCount = 0;

  bool _isPeerOnline = false;
  String _peerLastActive = '';
  bool _isPeerTyping = false;
  Timer? _typingDismissTimer;

  Timer? _fallbackTimer;
  Timer? _heartbeatTimer;
  int? _activeUserId;
  int? _activePeerId;

  List<ChatConversation> get conversations => _conversations;
  List<ChatMessage> get currentMessages => _currentMessages;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  int get totalUnreadCount => _totalUnreadCount;
  bool get isPusherActive => PusherConfig.isConfigured;
  bool get isPeerOnline => _isPeerOnline;
  String get peerLastActive => _peerLastActive;
  bool get isPeerTyping => _isPeerTyping;

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
      _isPeerTyping = false;
      notifyListeners();
    }

    try {
      final response = await _apiClient.get(
        '${ApiConstants.getMessages}?user_id=$userId&peer_id=$peerId',
      );

      // Status online/offline peer
      if (response['peer_status'] != null) {
        final pStatus = response['peer_status'] as Map<String, dynamic>;
        _isPeerOnline = pStatus['is_online'] == true;
        _peerLastActive = pStatus['last_active']?.toString() ?? '';
      }

      final rawList = response['data'] as List<dynamic>? ?? [];
      _currentMessages = rawList
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();

      // Reset unread count untuk peer ini di percakapan
      final index = _conversations.indexWhere((c) => c.peer.id == peerId);
      if (index != -1) {
        final conv = _conversations[index];
        _conversations[index] = ChatConversation(
          peer: conv.peer.copyWith(
            isOnline: _isPeerOnline,
            lastActive: _peerLastActive,
          ),
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

  /// Menangani pesan realtime baru dari Pusher
  void _handleIncomingMessage(dynamic rawData) {
    if (rawData == null || rawData is! Map<String, dynamic>) return;

    try {
      final msg = ChatMessage.fromJson(rawData);

      // Pastikan pesan milik percakapan yang sedang aktif
      final isRelevant = (_activeUserId != null && _activePeerId != null) &&
          ((msg.senderId == _activePeerId && msg.receiverId == _activeUserId) ||
              (msg.senderId == _activeUserId && msg.receiverId == _activePeerId));

      if (isRelevant) {
        // Reset animasi mengetik jika pesan baru sudah terkirim
        if (msg.senderId == _activePeerId) {
          _isPeerTyping = false;
          _typingDismissTimer?.cancel();
        }

        if (!_currentMessages.any((m) => m.id == msg.id)) {
          final isMine = _activeUserId != null && msg.senderId == _activeUserId;
          final adjustedMsg = ChatMessage(
            id: msg.id,
            senderId: msg.senderId,
            receiverId: msg.receiverId,
            message: msg.message,
            image: msg.image,
            replyTo: msg.replyTo,
            reactions: msg.reactions,
            isMine: isMine,
            isRead: msg.isRead,
            createDate: msg.createDate,
          );

          _currentMessages.add(adjustedMsg);

          // Jika pesan dari lawan bicara dan kita sedang membuka room, otomatis tandai dibaca di backend
          if (!isMine && _activeUserId != null && _activePeerId != null) {
            _apiClient.get(
              '${ApiConstants.getMessages}?user_id=$_activeUserId&peer_id=$_activePeerId&after_id=${msg.id}',
            ).catchError((_) => <String, dynamic>{});
          }

          // Perbarui conversation list jika ada
          final convIdx = _conversations.indexWhere((c) => c.peer.id == _activePeerId);
          if (convIdx != -1) {
            final conv = _conversations[convIdx];
            _conversations[convIdx] = ChatConversation(
              peer: conv.peer,
              lastMessage: adjustedMsg,
              unreadCount: 0,
            );
          }

          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[ChatViewModel] Gagal memproses pesan Pusher: $e');
    }
  }

  /// Menangani event bahwa pesan telah dibaca (Centang 2 Biru realtime)
  void _handleMessagesRead(dynamic rawData) {
    bool hasChanges = false;
    for (int i = 0; i < _currentMessages.length; i++) {
      if (_currentMessages[i].isMine && !_currentMessages[i].isRead) {
        _currentMessages[i] = _currentMessages[i].copyWith(isRead: true);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  /// Menangani event bubble mengetik realtime
  void _handleTyping(dynamic rawData) {
    if (rawData == null || rawData is! Map) return;
    try {
      final map = Map<String, dynamic>.from(rawData);
      final senderId = int.tryParse(map['user_id']?.toString() ?? '') ?? 0;
      final typing = map['is_typing'] == true || map['is_typing'] == 1 || map['is_typing'] == 'true';

      if (senderId == _activePeerId) {
        _isPeerTyping = typing;
        _typingDismissTimer?.cancel();
        if (typing) {
          // Otomatis sembunyikan jika tidak ada ketikan lanjutan dalam 3.5 detik
          _typingDismissTimer = Timer(const Duration(milliseconds: 3500), () {
            _isPeerTyping = false;
            notifyListeners();
          });
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Menangani event hapus pesan realtime
  void _handleMessageDeleted(dynamic rawData) {
    if (rawData == null || rawData is! Map) return;
    try {
      final map = Map<String, dynamic>.from(rawData);
      final msgId = int.tryParse(map['message_id']?.toString() ?? '') ?? 0;
      if (msgId > 0) {
        _currentMessages.removeWhere((m) => m.id == msgId);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Menangani event hapus percakapan realtime
  void _handleConversationDeleted(dynamic rawData) {
    _currentMessages.clear();
    notifyListeners();
  }

  /// Menangani event reaction pesan realtime
  void _handleMessageReaction(dynamic rawData) {
    if (rawData == null || rawData is! Map) return;
    try {
      final map = Map<String, dynamic>.from(rawData);
      final msgId = int.tryParse(map['message_id']?.toString() ?? '') ?? 0;
      if (msgId <= 0) return;

      final List<ChatReaction> reactsList = [];
      if (map['reactions'] is List) {
        for (final item in map['reactions'] as List) {
          if (item is Map) {
            reactsList.add(ChatReaction.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }

      final idx = _currentMessages.indexWhere((m) => m.id == msgId);
      if (idx != -1) {
        _currentMessages[idx] = _currentMessages[idx].copyWith(reactions: reactsList);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ChatViewModel] Error handling message reaction: $e');
    }
  }

  /// Mulai mendengarkan pesan masuk, status online, dan interaksi realtime
  void startListening({required int userId, required int peerId}) {
    stopListening();
    _activeUserId = userId;
    _activePeerId = peerId;

    if (PusherConfig.isConfigured) {
      // ── Realtime via Pusher ──
      _pusherService.initPusher(
        onNewMessage: _handleIncomingMessage,
        onMessagesRead: _handleMessagesRead,
      );
      _pusherService.setTypingCallback(_handleTyping);
      _pusherService.setMessageDeletedCallback(_handleMessageDeleted);
      _pusherService.setConversationDeletedCallback(_handleConversationDeleted);
      _pusherService.setMessageReactionCallback(_handleMessageReaction);

      _pusherService.subscribeToChat(userId: userId, peerId: peerId);
    } else {
      // ── Fallback Polling (jika belum isi API key Pusher) ──
      _fallbackTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        _pollNewMessages();
      });
    }

    // Heartbeat berkala (setiap 30 detik) untuk update status online & cek status peer
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendHeartbeat();
    });
  }

  void startPolling({required int userId, required int peerId}) {
    startListening(userId: userId, peerId: peerId);
  }

  void stopListening() {
    _pusherService.unsubscribeFromCurrent();
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _typingDismissTimer?.cancel();
    _typingDismissTimer = null;
    _activeUserId = null;
    _activePeerId = null;
    _isPeerTyping = false;
  }

  void stopPolling() {
    stopListening();
  }

  Future<void> _sendHeartbeat() async {
    if (_activeUserId == null || _activePeerId == null) return;

    try {
      final url = '${ApiConstants.heartbeat}?user_id=$_activeUserId&peer_id=$_activePeerId';
      final response = await _apiClient.get(url);
      if (response['peer_status'] != null) {
        final pStatus = response['peer_status'] as Map<String, dynamic>;
        final newOnline = pStatus['is_online'] == true;
        final newActive = pStatus['last_active']?.toString() ?? '';
        if (newOnline != _isPeerOnline || newActive != _peerLastActive) {
          _isPeerOnline = newOnline;
          _peerLastActive = newActive;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> _pollNewMessages() async {
    if (_activeUserId == null || _activePeerId == null) return;

    final lastId =
        _currentMessages.isNotEmpty ? _currentMessages.last.id : 0;

    try {
      final url =
          '${ApiConstants.getMessages}?user_id=$_activeUserId&peer_id=$_activePeerId&after_id=$lastId';
      final response = await _apiClient.get(url);

      if (response['peer_status'] != null) {
        final pStatus = response['peer_status'] as Map<String, dynamic>;
        _isPeerOnline = pStatus['is_online'] == true;
        _peerLastActive = pStatus['last_active']?.toString() ?? '';
      }

      final rawList = response['data'] as List<dynamic>? ?? [];

      bool hasNew = false;
      if (rawList.isNotEmpty) {
        final newMsgs = rawList
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();

        for (final msg in newMsgs) {
          if (!_currentMessages.any((m) => m.id == msg.id)) {
            _currentMessages.add(msg);
            hasNew = true;
          }
        }
      }

      // Periksa juga apakah ada pesan saya yang sudah dibaca lawan bicara
      if (_currentMessages.any((m) => m.isMine && !m.isRead)) {
        final checkUrl = '${ApiConstants.getMessages}?user_id=$_activeUserId&peer_id=$_activePeerId';
        final checkRes = await _apiClient.get(checkUrl);
        final checkList = checkRes['data'] as List<dynamic>? ?? [];
        for (final item in checkList) {
          final id = item['id'];
          final isRead = item['is_read'] == true || item['is_read'] == 1 || item['is_read'] == '1';
          final idx = _currentMessages.indexWhere((m) => m.id == id);
          if (idx != -1 && _currentMessages[idx].isRead != isRead) {
            _currentMessages[idx] = _currentMessages[idx].copyWith(isRead: isRead);
            hasNew = true;
          }
        }
      }

      if (hasNew) {
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Kirim sinyal status sedang mengetik
  Future<void> sendTypingStatus({
    required int userId,
    required int peerId,
    required bool isTyping,
  }) async {
    try {
      await _apiClient.post(
        ApiConstants.typing,
        body: {
          'user_id': userId,
          'peer_id': peerId,
          'is_typing': isTyping,
        },
      );
    } catch (_) {}
  }

  /// Kirim pesan teks biasa (opsional dengan reply pesan sebelumnya)
  Future<bool> sendMessage({
    required int senderId,
    required int receiverId,
    required String text,
    int? replyToId,
  }) async {
    if (text.trim().isEmpty) return false;

    _isSending = true;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'sender_id': senderId,
        'receiver_id': receiverId,
        'message': text.trim(),
      };
      if (replyToId != null) {
        body['reply_to_id'] = replyToId;
      }

      final response = await _apiClient.post(
        ApiConstants.sendMessage,
        body: body,
      );

      if (response['status'] == true && response['data'] != null) {
        final newMsg =
            ChatMessage.fromJson(response['data'] as Map<String, dynamic>);
        if (!_currentMessages.any((m) => m.id == newMsg.id)) {
          _currentMessages.add(newMsg);
        }

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

  /// Kirim foto di obrolan (dengan atau tanpa teks tambahan & reply)
  Future<bool> sendPhotoMessage({
    required int senderId,
    required int receiverId,
    String? caption,
    required Uint8List imageBytes,
    required String filename,
    int? replyToId,
  }) async {
    _isSending = true;
    notifyListeners();

    try {
      final fields = <String, String>{
        'sender_id': senderId.toString(),
        'receiver_id': receiverId.toString(),
        if (caption != null && caption.trim().isNotEmpty)
          'message': caption.trim(),
        if (replyToId != null) 'reply_to_id': replyToId.toString(),
      };

      final response = await _apiClient.uploadBytes(
        ApiConstants.sendMessage,
        bytes: imageBytes,
        filename: filename,
        fieldName: 'image',
        fields: fields,
      );

      if (response['status'] == true && response['data'] != null) {
        final newMsg =
            ChatMessage.fromJson(response['data'] as Map<String, dynamic>);
        if (!_currentMessages.any((m) => m.id == newMsg.id)) {
          _currentMessages.add(newMsg);
        }

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

  /// Hapus pesan tertentu (Tarik pesan untuk semua orang)
  Future<bool> deleteMessage({
    required int messageId,
    required int userId,
  }) async {
    try {
      final res = await _apiClient.post(
        ApiConstants.deleteMessage,
        body: {
          'message_id': messageId,
          'user_id': userId,
        },
      );

      if (res['status'] == true) {
        _currentMessages.removeWhere((m) => m.id == messageId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  /// Hapus seluruh riwayat percakapan dengan peer
  Future<bool> deleteConversation({
    required int userId,
    required int peerId,
  }) async {
    try {
      final res = await _apiClient.post(
        ApiConstants.deleteConversation,
        body: {
          'user_id': userId,
          'peer_id': peerId,
        },
      );

      if (res['status'] == true) {
        _currentMessages.clear();
        _conversations.removeWhere((c) => c.peer.id == peerId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  /// Toggle Reaction Emoji pada pesan tertentu
  Future<bool> toggleReaction({
    required int messageId,
    required int userId,
    required String emoji,
  }) async {
    try {
      final res = await _apiClient.post(
        ApiConstants.reactMessage,
        body: {
          'message_id': messageId,
          'user_id': userId,
          'emoji': emoji,
        },
      );

      if (res['status'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final List<ChatReaction> reactsList = [];
        if (data['reactions'] is List) {
          for (final item in data['reactions'] as List) {
            if (item is Map) {
              reactsList.add(ChatReaction.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }

        final idx = _currentMessages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          _currentMessages[idx] = _currentMessages[idx].copyWith(reactions: reactsList);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
