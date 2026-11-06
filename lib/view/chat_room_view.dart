import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
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
  bool _canSend = false;
  ChatViewModel? _chatVm;
  int _lastMessageCount = 0;
  final Set<int> _likedMessageIds = {};

  static const Color instagramBlue = Color(0xFF3797EF);
  static const Color primaryBlue = Color(0xFF3366A0);

  @override
  void initState() {
    super.initState();
    _msgController.addListener(() {
      final can = _msgController.text.trim().isNotEmpty;
      if (can != _canSend) {
        setState(() => _canSend = can);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initChat();
    });
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

      _chatVm?.startPolling(userId: userId, peerId: widget.peer.id);
    }
  }

  @override
  void dispose() {
    _chatVm?.stopPolling();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        maxScroll + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  bool _isMine(ChatMessage msg, int currentUserId) {
    // Jika senderId sama persis dengan peer.id, pasti BUKAN dari user kita
    if (widget.peer.id > 0 && msg.senderId == widget.peer.id) {
      return false;
    }
    // Jika senderId sama dengan id user saat ini, pasti dari user kita
    if (currentUserId > 0 && msg.senderId == currentUserId) {
      return true;
    }
    // Dalam obrolan 1-lawan-1, jika senderId bukan peer.id maka pasti milik kita
    if (widget.peer.id > 0 && msg.senderId > 0 && msg.senderId != widget.peer.id) {
      return true;
    }
    // Fallback ke flag isMine
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

    final chatVm = context.read<ChatViewModel>();
    final success = await chatVm.sendMessage(
      senderId: userId,
      receiverId: widget.peer.id,
      text: text,
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

  void _sendQuickHeart() {
    _handleSend(overrideText: '❤️');
  }

  void _toggleLike(int messageId) {
    if (messageId <= 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (_likedMessageIds.contains(messageId)) {
        _likedMessageIds.remove(messageId);
      } else {
        _likedMessageIds.add(messageId);
      }
    });
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
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
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
          // Avatar besar khas Instagram DM
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
          // Tombol "Lihat Profil" Instagram style
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
                    Text(
                      '@${widget.peer.username}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF8E8E8E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined,
                color: Color(0xFF262626), size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Panggilan suara akan segera hadir!'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Telepon',
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined,
                color: Color(0xFF262626), size: 24),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Panggilan video akan segera hadir!'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Panggilan Video',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: Color(0xFF262626), size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileView(userId: widget.peer.id),
                ),
              );
            },
            tooltip: 'Detail Profil',
          ),
          const Gap(4),
        ],
      ),
      body: Column(
        children: [
          // Daftar Pesan (Instagram DM style)
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
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, index) {
                      // Index 0 adalah Thread Header khas Instagram
                      if (index == 0) {
                        return _buildThreadHeader();
                      }

                      final msgIndex = index - 1;
                      final msg = messages[msgIndex];
                      final isMine = _isMine(msg, currentUserId);
                      final isLiked = _likedMessageIds.contains(msg.id);

                      // Cek pemisah hari jika hari berbeda dengan pesan sebelumnya
                      bool showDateHeader = false;
                      if (msgIndex == 0) {
                        showDateHeader = true;
                      } else {
                        final prevMsg = messages[msgIndex - 1];
                        showDateHeader = _isDifferentDay(
                            prevMsg.createDate, msg.createDate);
                      }

                      // Menentukan apakah avatar peer perlu ditampilkan di bubble kiri
                      // Hanya tampilkan avatar di pesan terakhir dari grup pesan penerima
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
                          GestureDetector(
                            onDoubleTap: () => _toggleLike(msg.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              child: Row(
                                mainAxisAlignment: isMine
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Avatar peer di sisi kiri jika pesan dari lawan bicara
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
                                                0.72,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 15, vertical: 10),
                                          decoration: BoxDecoration(
                                            // Instagram gradient jika pesan kita (Kanan)
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
                                            // Instagram light gray jika pesan lawan bicara (Kiri)
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
                                          child: Wrap(
                                            alignment: WrapAlignment.end,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.end,
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                msg.message,
                                                style: TextStyle(
                                                  color: isMine
                                                      ? Colors.white
                                                      : const Color(0xFF262626),
                                                  fontSize: 15,
                                                  height: 1.35,
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _formatTime(msg.createDate),
                                                    style: TextStyle(
                                                      color: isMine
                                                          ? Colors.white
                                                              .withValues(
                                                                  alpha: 0.7)
                                                          : const Color(
                                                              0xFF8E8E8E),
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  if (isMine) ...[
                                                    const SizedBox(width: 3),
                                                    Icon(
                                                      msg.isRead
                                                          ? Icons
                                                              .done_all_rounded
                                                          : Icons.done_rounded,
                                                      size: 13,
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.8),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Indikator Love khas Instagram jika di-double-tap
                                        if (isLiked)
                                          Positioned(
                                            bottom: -9,
                                            right: isMine ? 8 : null,
                                            left: isMine ? null : 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(2.5),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.12),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.favorite,
                                                size: 15,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isLiked) const Gap(6),
                        ],
                      );
                    },
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
                  // Input Pill khas Instagram
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
                          // Tombol Kamera Biru khas Instagram
                          Padding(
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
                          const Gap(6),

                          // Kolom Input Teks Pesan
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              maxLines: 5,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF262626),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Kirim pesan...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8E8E8E),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),

                          // Tombol Aksi saat teks kosong (Mic, Galeri, Love cepat)
                          if (!_canSend) ...[
                            IconButton(
                              icon: const Icon(Icons.mic_none_rounded,
                                  size: 22, color: Color(0xFF262626)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 38),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pesan suara segera hadir!'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.image_outlined,
                                  size: 22, color: Color(0xFF262626)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 38),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Kirim foto segera hadir!'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
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

                          // Tombol "Kirim" Teks Biru khas Instagram saat teks ada
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
