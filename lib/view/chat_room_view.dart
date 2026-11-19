import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/chat_model.dart';
import 'package:ziesocial/view/profile_view.dart';
import 'package:ziesocial/viewmodel/chat_viewmodel.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';

class ChatRoomView extends StatefulWidget {
  final ChatPeer peer;

  const ChatRoomView({super.key, required this.peer});

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _canSend = false;
  ChatViewModel? _chatVm;
  int _lastMessageCount = 0;

  ChatMessage? _replyingTo;
  Timer? _typingDebounce;
  bool _sentTypingActive = false;

  static const Color instagramBlue = Color(0xFF3797EF);
  static const Color primaryBlue = Color(0xFF3366A0);

  final List<String> _quickEmojis = ['❤️', '😂', '😮', '😢', '👏', '🔥'];

  @override
  void initState() {
    super.initState();

    _msgController.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initChat();
    });
  }

  void _onTextChanged() {
    final can = _msgController.text.trim().isNotEmpty;
    if (can != _canSend) {
      setState(() => _canSend = can);
    }

    // Kirim sinyal typing
    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId <= 0) return;

    if (can) {
      if (!_sentTypingActive) {
        _sentTypingActive = true;
        _chatVm?.sendTypingStatus(
          userId: userId,
          peerId: widget.peer.id,
          isTyping: true,
        );
      }
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(milliseconds: 2500), () {
        _sentTypingActive = false;
        _chatVm?.sendTypingStatus(
          userId: userId,
          peerId: widget.peer.id,
          isTyping: false,
        );
      });
    } else if (_sentTypingActive) {
      _sentTypingActive = false;
      _typingDebounce?.cancel();
      _chatVm?.sendTypingStatus(
        userId: userId,
        peerId: widget.peer.id,
        isTyping: false,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatVm ??= context.read<ChatViewModel>();
  }

  void _initChat() {
    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId > 0) {
      _chatVm?.fetchMessages(
        userId: userId,
        peerId: widget.peer.id,
        isInitial: true,
      ).then((_) {
        if (mounted) _scrollToBottom(animated: false);
      });

      _chatVm?.startListening(userId: userId, peerId: widget.peer.id);
    }
  }

  @override
  void dispose() {
    // Matikan sinyal typing jika masih aktif
    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId > 0 && _sentTypingActive) {
      _chatVm?.sendTypingStatus(
        userId: userId,
        peerId: widget.peer.id,
        isTyping: false,
      );
    }
    _typingDebounce?.cancel();
    _chatVm?.stopListening();
    _msgController.removeListener(_onTextChanged);
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        maxScroll + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  bool _isMine(ChatMessage msg, int currentUserId) {
    if (widget.peer.id > 0 && msg.senderId == widget.peer.id) {
      return false;
    }
    if (currentUserId > 0 && msg.senderId == currentUserId) {
      return true;
    }
    if (widget.peer.id > 0 && msg.senderId > 0 && msg.senderId != widget.peer.id) {
      return true;
    }
    return msg.isMine;
  }

  Future<void> _handleSend({String? overrideText}) async {
    final text = (overrideText ?? _msgController.text).trim();
    if (text.isEmpty) return;

    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId <= 0) return;

    HapticFeedback.lightImpact();
    if (overrideText == null) {
      _msgController.clear();
    }

    final replyId = _replyingTo?.id;
    setState(() => _replyingTo = null);

    // Stop status typing
    _sentTypingActive = false;
    _typingDebounce?.cancel();
    _chatVm?.sendTypingStatus(
      userId: userId,
      peerId: widget.peer.id,
      isTyping: false,
    );

    final chatVm = context.read<ChatViewModel>();
    final success = await chatVm.sendMessage(
      senderId: userId,
      receiverId: widget.peer.id,
      text: text,
      replyToId: replyId,
    );

    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: true);
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatVm.errorMessage ?? 'Gagal mengirim pesan'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Memilih foto dari galeri atau kamera lalu mengirimnya
  Future<void> _pickAndSendPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (!mounted) return;

      final user = context.read<LoginViewModel>().user;
      final userId = int.tryParse(user?.id ?? '') ?? 0;
      if (userId <= 0) return;

      final bytes = await picked.readAsBytes();
      final filename = picked.name.isNotEmpty
          ? picked.name
          : 'chat_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final caption = _msgController.text.trim();
      final replyId = _replyingTo?.id;
      setState(() => _replyingTo = null);

      if (!mounted) return;
      final chatVm = context.read<ChatViewModel>();
      final success = await chatVm.sendPhotoMessage(
        senderId: userId,
        receiverId: widget.peer.id,
        imageBytes: bytes,
        filename: filename,
        caption: caption.isNotEmpty ? caption : null,
        replyToId: replyId,
      );

      if (success) {
        _msgController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animated: true);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(chatVm.errorMessage ?? 'Gagal mengirim foto'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showMediaPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Kirim Foto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF262626),
                ),
              ),
              const Gap(16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: primaryBlue),
                ),
                title: const Text('Ambil Foto dari Kamera',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: primaryBlue),
                ),
                title: const Text('Pilih dari Galeri',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendQuickHeart() {
    _handleSend(overrideText: '❤️');
  }

  /// Toggle Reaction pada pesan
  void _toggleReaction(ChatMessage msg, String emoji) {
    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId <= 0) return;

    HapticFeedback.lightImpact();
    context.read<ChatViewModel>().toggleReaction(
      messageId: msg.id,
      userId: userId,
      emoji: emoji,
    );
  }

  /// Tampilkan Dialog / Modal Menu Pesan (Reaction, Reply, Hapus Pesan)
  void _showMessageOptionsSheet(ChatMessage msg, bool isMine) {
    HapticFeedback.mediumImpact();
    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Baris Reaction Emoji Cepat (Instagram Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _quickEmojis.map((emoji) {
                  final isSelected = msg.myReaction(userId) == emoji;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleReaction(msg, emoji);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryBlue.withValues(alpha: 0.18)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: isSelected ? 26 : 22),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Gap(14),

            // Opsi: Balas Pesan (Reply)
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: primaryBlue),
              title: const Text('Balas Pesan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = msg);
                _focusNode.requestFocus();
              },
            ),

            // Opsi: Salin Teks
            if (msg.message.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF475569)),
                title: const Text('Salin Teks',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msg.message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Teks disalin ke papan klip'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

            // Opsi: Hapus Pesan (Tarik Pesan untuk semua)
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text(
                  'Tarik / Hapus Pesan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteMessage(msg.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Konfirmasi Hapus Pesan
  void _confirmDeleteMessage(int messageId) {
    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId <= 0) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pesan?'),
        content: const Text(
          'Pesan ini akan ditarik dan dihapus untuk semua orang dalam percakapan.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChatViewModel>().deleteMessage(
                    messageId: messageId,
                    userId: userId,
                  );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  /// Konfirmasi Hapus Seluruh Percakapan (Clear Chat)
  void _confirmDeleteConversation() {
    final user = context.read<LoginViewModel>().user;
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    if (userId <= 0) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Obrolan?'),
        content: Text(
          'Seluruh riwayat pesan dengan ${widget.peer.name.isNotEmpty ? widget.peer.name : widget.peer.username} akan dihapus secara permanen.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<ChatViewModel>().deleteConversation(
                    userId: userId,
                    peerId: widget.peer.id,
                  );
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Obrolan berhasil dihapus.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text(
                    'Gagal memuat gambar',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min';
    } catch (_) {
      return '';
    }
  }

  String _formatDateHeader(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Hari ini';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.year == yesterday.year &&
          dt.month == yesterday.month &&
          dt.day == yesterday.day) {
        return 'Kemarin';
      }
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  bool _isDifferentDay(String dateStr1, String dateStr2) {
    try {
      final dt1 = DateTime.parse(dateStr1.replaceAll(' ', 'T'));
      final dt2 = DateTime.parse(dateStr2.replaceAll(' ', 'T'));
      return dt1.year != dt2.year ||
          dt1.month != dt2.month ||
          dt1.day != dt2.day;
    } catch (_) {
      return false;
    }
  }

  Widget _buildThreadHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 20, left: 16, right: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: const Color(0xFFE2E8F0),
              child: widget.peer.avatar.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        widget.peer.avatarUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                          widget.peer.name.isNotEmpty
                              ? widget.peer.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      widget.peer.name.isNotEmpty
                          ? widget.peer.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
            ),
          ),
          const Gap(12),
          Text(
            widget.peer.name.isNotEmpty
                ? widget.peer.name
                : widget.peer.username,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF262626),
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(2),
          Text(
            '@${widget.peer.username} • ZieSocial',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8E8E8E),
            ),
          ),
          const Gap(14),
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileView(userId: widget.peer.id),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFEFEFEF),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Lihat Profil',
              style: TextStyle(
                color: Color(0xFF262626),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }

  /// Bubble animasi titik mengetik khas Instagram / iMessage
  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFE2E8F0),
            child: widget.peer.avatar.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      widget.peer.avatarUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Text(
                        widget.peer.name.isNotEmpty
                            ? widget.peer.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                : Text(
                    widget.peer.name.isNotEmpty
                        ? widget.peer.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFEFEFEF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const _AnimatedTypingDots(),
          ),
        ],
      ),
    );
  }

  /// Box Quoted Message di dalam bubble chat (ketika membalas pesan)
  Widget _buildQuotedMessagePreview(ChatReply reply, bool isMine) {
    final hasImage = reply.imageUrl != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.black.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.white : primaryBlue,
            width: 3.5,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reply.senderName.isNotEmpty
                      ? reply.senderName
                      : reply.senderUsername,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isMine ? Colors.white : primaryBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  reply.message.isNotEmpty
                      ? reply.message
                      : (hasImage ? '📷 Foto' : ''),
                  style: TextStyle(
                    fontSize: 12,
                    color: isMine ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasImage) ...[
            const Gap(6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                reply.imageUrl!,
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Reaction badges pada tepi bubble chat
  Widget _buildReactionBadge(ChatMessage msg, bool isMine, int currentUserId) {
    final counts = msg.reactionCounts;
    if (counts.isEmpty) return const SizedBox.shrink();

    final myReact = msg.myReaction(currentUserId);

    return Positioned(
      bottom: -10,
      right: isMine ? 8 : null,
      left: isMine ? null : 8,
      child: GestureDetector(
        onTap: () => _showMessageOptionsSheet(msg, isMine),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: myReact != null
                  ? primaryBlue.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: counts.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Text(
                  '${e.key}${e.value > 1 ? ' ${e.value}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        int.tryParse(context.watch<LoginViewModel>().user?.id ?? '') ?? 0;
    final chatVm = context.watch<ChatViewModel>();
    final messages = chatVm.currentMessages;

    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom(animated: true);
      });
    }

    final totalListCount = messages.length + 1 + (chatVm.isPeerTyping ? 1 : 0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: const Color(0xFFEFEFEF),
            height: 0.5,
          ),
        ),
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF262626)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileView(userId: widget.peer.id),
              ),
            );
          },
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: widget.peer.avatar.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              widget.peer.avatarUrl,
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Text(
                                widget.peer.name.isNotEmpty
                                    ? widget.peer.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            widget.peer.name.isNotEmpty
                                ? widget.peer.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                  if (chatVm.isPeerOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.peer.name.isNotEmpty
                          ? widget.peer.name
                          : widget.peer.username,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF262626),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (chatVm.isPeerTyping) ...[
                          const Text(
                            'sedang mengetik...',
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryBlue,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else if (chatVm.isPeerOnline) ...[
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Text(
                            'Aktif sekarang',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else ...[
                          Text(
                            chatVm.peerLastActive.isNotEmpty
                                ? chatVm.peerLastActive
                                : '@${widget.peer.username}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8E8E8E),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Menu Opsi Obrolan (Hapus Obrolan, Lihat Profil)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF262626)),
            onSelected: (val) {
              if (val == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileView(userId: widget.peer.id),
                  ),
                );
              } else if (val == 'delete_chat') {
                _confirmDeleteConversation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF475569)),
                    Gap(10),
                    Text('Lihat Profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_chat',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.red),
                    Gap(10),
                    Text('Hapus Obrolan', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const Gap(4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatVm.isLoadingMessages
                ? const Center(
                    child: CircularProgressIndicator(
                      color: primaryBlue,
                      strokeWidth: 2,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 14),
                    itemCount: totalListCount,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildThreadHeader();
                      }

                      // Menampilkan bubble mengetik di item paling bawah jika aktif
                      if (chatVm.isPeerTyping && index == totalListCount - 1) {
                        return _buildTypingBubble();
                      }

                      final msgIndex = index - 1;
                      final msg = messages[msgIndex];
                      final isMine = _isMine(msg, currentUserId);

                      bool showDateHeader = false;
                      if (msgIndex == 0) {
                        showDateHeader = true;
                      } else {
                        final prevMsg = messages[msgIndex - 1];
                        showDateHeader = _isDifferentDay(
                            prevMsg.createDate, msg.createDate);
                      }

                      final bool isLastInReceivedGroup = !isMine &&
                          ((msgIndex == messages.length - 1) ||
                              _isMine(messages[msgIndex + 1], currentUserId) ||
                              _isDifferentDay(msg.createDate,
                                  messages[msgIndex + 1].createDate));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateHeader)
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  _formatDateHeader(msg.createDate),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8E8E8E),
                                  ),
                                ),
                              ),
                            ),

                          // Swipe to reply / Double tap / Long press
                          GestureDetector(
                            onDoubleTap: () => _toggleReaction(msg, '❤️'),
                            onLongPress: () =>
                                _showMessageOptionsSheet(msg, isMine),
                            child: Dismissible(
                              key: ValueKey('msg_${msg.id}'),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (dir) async {
                                HapticFeedback.lightImpact();
                                setState(() => _replyingTo = msg);
                                _focusNode.requestFocus();
                                return false; // Jangan hapus dari list saat swipe reply
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Icon(
                                  Icons.reply_rounded,
                                  color: primaryBlue,
                                  size: 24,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 3),
                                child: Row(
                                  mainAxisAlignment: isMine
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isMine) ...[
                                      if (isLastInReceivedGroup)
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor:
                                              const Color(0xFFE2E8F0),
                                          child: widget.peer.avatar.isNotEmpty
                                              ? ClipOval(
                                                  child: Image.network(
                                                    widget.peer.avatarUrl,
                                                    width: 28,
                                                    height: 28,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error,
                                                            stackTrace) =>
                                                        Text(
                                                      widget.peer.name.isNotEmpty
                                                          ? widget.peer.name[0]
                                                              .toUpperCase()
                                                          : '?',
                                                      style: const TextStyle(
                                                        color: primaryBlue,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  widget.peer.name.isNotEmpty
                                                      ? widget.peer.name[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    color: primaryBlue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                        )
                                      else
                                        const SizedBox(width: 28),
                                      const Gap(8),
                                    ],

                                    // Bubble Pesan
                                    Flexible(
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.75,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: msg.imageUrl != null ? 6 : 14,
                                              vertical: msg.imageUrl != null ? 6 : 10,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: isMine
                                                  ? const LinearGradient(
                                                      colors: [
                                                        Color(0xFF7825EB),
                                                        Color(0xFF0075FF),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    )
                                                  : null,
                                              color: isMine
                                                  ? null
                                                  : const Color(0xFFEFEFEF),
                                              borderRadius: BorderRadius.only(
                                                topLeft:
                                                    const Radius.circular(20),
                                                topRight:
                                                    const Radius.circular(20),
                                                bottomLeft: Radius.circular(
                                                    isMine ? 20 : 4),
                                                bottomRight: Radius.circular(
                                                    isMine ? 4 : 20),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: isMine
                                                  ? CrossAxisAlignment.end
                                                  : CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Tampilan Pesan yang di-Reply
                                                if (msg.replyTo != null)
                                                  _buildQuotedMessagePreview(
                                                      msg.replyTo!, isMine),

                                                // Tampilan Foto dalam Chat
                                                if (msg.imageUrl != null) ...[
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(15),
                                                    child: GestureDetector(
                                                      onTap: () =>
                                                          _openFullScreenImage(
                                                              context,
                                                              msg.imageUrl!),
                                                      child: Stack(
                                                        children: [
                                                          Image.network(
                                                            msg.imageUrl!,
                                                            width: 240,
                                                            height: 240,
                                                            fit: BoxFit.cover,
                                                            loadingBuilder: (context,
                                                                child, progress) {
                                                              if (progress == null) {
                                                                return child;
                                                              }
                                                              return Container(
                                                                width: 240,
                                                                height: 240,
                                                                color:
                                                                    Colors.black12,
                                                                child: const Center(
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                    strokeWidth: 2,
                                                                    color:
                                                                        Colors.white,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            errorBuilder: (context,
                                                                    error,
                                                                    stackTrace) =>
                                                                Container(
                                                              width: 240,
                                                              height: 140,
                                                              color: Colors.black12,
                                                              child: const Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .broken_image_rounded,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  if (msg.message.isNotEmpty)
                                                    const Gap(6),
                                                ],

                                                // Teks Pesan
                                                if (msg.message.isNotEmpty)
                                                  Padding(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal:
                                                          msg.imageUrl != null ? 8 : 0,
                                                      vertical:
                                                          msg.imageUrl != null ? 4 : 0,
                                                    ),
                                                    child: Text(
                                                      msg.message,
                                                      style: TextStyle(
                                                        color: isMine
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF262626),
                                                        fontSize: 15,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ),

                                                // Bar Waktu & Status Centang 2 (Read Receipts)
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                    top: 2,
                                                    right:
                                                        msg.imageUrl != null ? 6 : 0,
                                                    left:
                                                        msg.imageUrl != null ? 6 : 0,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        _formatTime(msg.createDate),
                                                        style: TextStyle(
                                                          color: isMine
                                                              ? Colors.white
                                                                  .withValues(
                                                                      alpha: 0.75)
                                                              : const Color(
                                                                  0xFF8E8E8E),
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                      if (isMine) ...[
                                                        const SizedBox(width: 4),
                                                        Icon(
                                                          Icons.done_all_rounded,
                                                          size: 15,
                                                          color: msg.isRead
                                                              ? const Color(0xFF38E1FF)
                                                              : Colors.white.withValues(alpha: 0.65),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Emoji Reaction Badges
                                          _buildReactionBadge(msg, isMine, currentUserId),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (msg.reactions.isNotEmpty) const Gap(8),
                        ],
                      );
                    },
                  ),
          ),

          // Container Preview Membalas Pesan (Reply Banner)
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                  left: BorderSide(color: primaryBlue, width: 4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Membalas ke ${_isMine(_replyingTo!, currentUserId) ? 'Anda' : widget.peer.name}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          _replyingTo!.message.isNotEmpty
                              ? _replyingTo!.message
                              : (_replyingTo!.imageUrl != null
                                  ? '📷 Foto'
                                  : ''),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_replyingTo!.imageUrl != null) ...[
                    const Gap(8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        _replyingTo!.imageUrl!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          // Bottom Bar Input Khas Instagram DM
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFEFEFEF), width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Tombol Kamera Cepat
                          GestureDetector(
                            onTap: () => _pickAndSendPhoto(ImageSource.camera),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 4),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: instagramBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          const Gap(6),

                          // Kolom Input Teks Pesan
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              focusNode: _focusNode,
                              maxLines: 5,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF262626),
                              ),
                              decoration: InputDecoration(
                                hintText: _replyingTo != null
                                    ? 'Tulis balasan...'
                                    : 'Kirim pesan...',
                                hintStyle: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8E8E8E),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),

                          // Tombol Galeri Foto
                          IconButton(
                            icon: const Icon(Icons.image_outlined,
                                size: 22, color: Color(0xFF262626)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 38),
                            onPressed: _showMediaPickerSheet,
                            tooltip: 'Kirim Foto dari Galeri',
                          ),

                          // Tombol Aksi saat teks kosong (Love cepat)
                          if (!_canSend) ...[
                            IconButton(
                              icon: const Icon(Icons.favorite_border_rounded,
                                  size: 22, color: Color(0xFF262626)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 38),
                              onPressed: _sendQuickHeart,
                              tooltip: 'Kirim Love ❤️',
                            ),
                          ],

                          // Tombol "Kirim"
                          if (_canSend)
                            Padding(
                              padding: const EdgeInsets.only(
                                  right: 8, bottom: 8, top: 8),
                              child: GestureDetector(
                                onTap: chatVm.isSending ? null : () => _handleSend(),
                                child: chatVm.isSending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: instagramBlue,
                                        ),
                                      )
                                    : const Text(
                                        'Kirim',
                                        style: TextStyle(
                                          color: instagramBlue,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget 3 titik bergelombang halus untuk indikator bubble sedang mengetik
class _AnimatedTypingDots extends StatefulWidget {
  const _AnimatedTypingDots();

  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final val = (_controller.value - (i * 0.2)) % 1.0;
              final offset = (val < 0.5)
                  ? -3.5 * (1 - (val * 2 - 0.5).abs() * 2)
                  : 0.0;
              return Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8E8E8E),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
